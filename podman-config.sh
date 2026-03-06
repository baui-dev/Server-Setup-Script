#!/bin/bash
# Podman installation functions
# Provides: apply_podman_install(), setup_podman_rootless()
# Requires: add_alvistack_apt_source() from sources-list.sh

# Install Podman from the selected source.
apply_podman_install() {
    local source="${1:-github}"
    case "$source" in
        debian)
            apt-get update -qq
            DEBIAN_FRONTEND=noninteractive apt-get install -y \
                podman podman-compose
            _setup_podman_config
            ;;
        alvistack)
            add_alvistack_apt_source
            DEBIAN_FRONTEND=noninteractive apt-get install -y \
                podman podman-compose
            _setup_podman_config
            ;;
        github|*)
            _install_podman_github
            _setup_podman_config
            ;;
    esac
}

# Install the latest Podman release binary from GitHub.
_install_podman_github() {
    local target_user
    target_user="${ADMIN_USER:-${SUDO_USER:-root}}"
    local target_home
    target_home="$([[ "$target_user" == "root" ]] && echo "/root" || echo "/home/$target_user")"

    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        git uidmap fuse3 fuse-overlayfs python3-full python3-pip python3-venv curl

    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    local download_url
    download_url="$(
        curl -s https://api.github.com/repos/containers/podman/releases/latest \
        | grep '"browser_download_url"' \
        | grep 'podman-remote-static-linux_amd64.tar.gz"' \
        | head -1 \
        | cut -d '"' -f 4
    )"

    if [[ -z "$download_url" ]]; then
        echo "install_podman_github: could not fetch release URL from GitHub API" >&2
        return 1
    fi

    curl -sL "$download_url" -o "${tmp_dir}/podman.tar.gz"
    tar --strip-components=2 -xzf "${tmp_dir}/podman.tar.gz" \
        -C /usr/local/bin bin/podman
    chmod +x /usr/local/bin/podman

    # podman-compose via venv (scoped to admin user)
    local venv_dir="${target_home}/.venv"
    python3 -m venv "$venv_dir"
    "${venv_dir}/bin/pip3" install --quiet --upgrade pip
    "${venv_dir}/bin/pip3" install --quiet podman-compose
    chmod +x "${venv_dir}/bin/podman-compose"
    chown -R "${target_user}:${target_user}" "$venv_dir"

    # Persist PATH for both interactive (.bashrc) and login (.profile) shells
    for rc_file in "${target_home}/.bashrc" "${target_home}/.profile"; do
        grep -q "venv/bin" "$rc_file" 2>/dev/null \
            || echo "export PATH=\"\$PATH:${venv_dir}/bin\"" >> "$rc_file"
    done
}

# Common post-install configuration applied for any Podman installation.
_setup_podman_config() {
    local target_user
    target_user="${ADMIN_USER:-${SUDO_USER:-root}}"
    local target_home
    target_home="$([[ "$target_user" == "root" ]] && echo "/root" || echo "/home/$target_user")"

    # Keep containers running after logout
    loginctl enable-linger "$target_user" || true

    # Allow unprivileged containers to bind ports ≥80
    echo "net.ipv4.ip_unprivileged_port_start=80" \
        > /etc/sysctl.d/50-podman-unprivileged-ports.conf
    sysctl --load /etc/sysctl.d/50-podman-unprivileged-ports.conf >/dev/null

    # Create config directories and configure registries as the target user
    # Use 'su' rather than 'sudo' when already root to avoid the sudo
    # dependency on a minimal fresh system
    if [[ "$(id -u)" -eq 0 && "$target_user" != "root" ]]; then
        su - "$target_user" -s /bin/bash << HEREDOC
set -e
mkdir -p "\$HOME/podman" "\$HOME/.config/systemd/user" "\$HOME/.config/containers"

# Container registries
if [[ -f /etc/containers/registries.conf ]]; then
    cp /etc/containers/registries.conf "\$HOME/.config/containers/"
fi

# Ensure docker.io, ghcr.io and quay.io are always searched
if ! grep -q 'docker.io' "\$HOME/.config/containers/registries.conf" 2>/dev/null; then
    cat >> "\$HOME/.config/containers/registries.conf" << 'EOF'
[registries.search]
registries = ['docker.io', 'ghcr.io', 'quay.io']
EOF
fi

# Enable the Podman socket for API-compatible tools (e.g. Portainer)
systemctl --user enable --now podman.socket 2>/dev/null || true

# Convenience aliases
for rc_file in "\$HOME/.bashrc" "\$HOME/.profile"; do
    grep -q 'alias docker=podman' "\$rc_file" 2>/dev/null && continue
    echo "alias docker=podman"         >> "\$rc_file"
    echo "alias docker-compose=podman-compose" >> "\$rc_file"
done
HEREDOC
    fi
}

# Configure rootless Podman for a specific user (called separately when
# CONTAINER_ENGINE=podman-rootless)
setup_podman_rootless() {
    local target_user="${1:-${ADMIN_USER:-}}"

    if [[ -z "$target_user" || "$target_user" == "root" ]]; then
        echo "setup_podman_rootless: a non-root user is required" >&2
        return 1
    fi

    loginctl enable-linger "$target_user" || true

    echo "  Rootless Podman configured for ${target_user}."
    echo "  Run 'systemctl --user status podman.socket' as ${target_user} to verify."
}
