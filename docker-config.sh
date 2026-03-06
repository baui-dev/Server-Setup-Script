#!/bin/bash
# Docker installation functions
# Provides: install_docker(), install_docker_rootless()
# Requires: add_docker_apt_source() from sources-list.sh

install_docker() {
    add_docker_apt_source
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
    echo "Docker installed successfully."
}

install_docker_rootless() {
    local target_user="${1:-}"

    if [[ -z "$target_user" ]]; then
        echo "install_docker_rootless: target user is required" >&2
        return 1
    fi
    if [[ "$target_user" == "root" ]]; then
        echo "install_docker_rootless: rootless Docker cannot run as root" >&2
        return 1
    fi
    if ! id -u "$target_user" >/dev/null 2>&1; then
        echo "install_docker_rootless: user '${target_user}' does not exist" >&2
        return 1
    fi

    # System-level dependencies
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        uidmap dbus-user-session slirp4netns curl

    # Enable lingering so user services survive logout
    loginctl enable-linger "$target_user" || true

    # Run the official rootless installer as the target user
    sudo -iu "$target_user" bash -lc '
        set -e
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
        export PATH="$HOME/bin:$PATH"
        curl -fsSL https://get.docker.com/rootless | sh
        # Persist environment for future sessions
        grep -q "DOCKER_HOST" "$HOME/.bashrc" 2>/dev/null || {
            echo "export PATH=\"\$HOME/bin:\$PATH\""                         >> "$HOME/.bashrc"
            echo "export DOCKER_HOST=\"unix://\$XDG_RUNTIME_DIR/docker.sock\"" >> "$HOME/.bashrc"
        }
        grep -q "DOCKER_HOST" "$HOME/.profile" 2>/dev/null || {
            echo "export PATH=\"\$HOME/bin:\$PATH\""                         >> "$HOME/.profile"
            echo "export DOCKER_HOST=\"unix://\$XDG_RUNTIME_DIR/docker.sock\"" >> "$HOME/.profile"
        }
        systemctl --user enable --now docker.service || true
    '

    echo "Docker (rootless) installed for user ${target_user}."
}
