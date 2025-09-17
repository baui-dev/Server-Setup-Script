#!/bin/bash

# Function to get target user
get_target_user() {
    if [[ $EUID -eq 0 ]]; then
        # Running as root, get the actual user
        echo "${SUDO_USER:-root}"
    else
        # Running as regular user
        echo "$USER"
    fi
}

# Use Github release, debian or alvistack repo?
choose_podman_source() {
    echo "Choose Podman source:"
    echo "1. Github release (standard)"
    echo "2. Debian repository"
    echo "3. Alvistack repository"
    read -p "Select option (1/3): " PODMAN_SOURCE

    case "$PODMAN_SOURCE" in
    2)
        echo "Using Debian repository..."
        apt install -y podman podman-compose podman-netavark
        setup_podman_config
        ;;
    3)
        echo "Using Alvistack repository..."
        install_podman_alvistack
        setup_podman_config
        ;;
    *)
        echo "Using Github release..."
        install_podman_github
        setup_podman_config
        ;;
    esac
}

choose_podman_source_prompt() {
    local choice
    echo "Choose Podman source:"
    echo "1) Github release (standard)"
    echo "2) Debian repository"
    echo "3) Alvistack repository"
    read -r -p "Select option (1-3) [1]: " choice
    case "$choice" in
        2) echo "debian" ;;
        3) echo "alvistack" ;;
        *) echo "github" ;;
    esac
}

apply_podman_install() {
    local source="$1"
    case "$source" in
        debian)
            apt-get update && apt-get install -y podman podman-compose podman-netavark
            setup_podman_config
            ;;
        alvistack)
            install_podman_alvistack
            setup_podman_config
            ;;
        github|*)
            install_podman_github
            setup_podman_config
            ;;
    esac
}

# Install Podman from Github release
install_podman_github() {
    TARGET_USER=$(get_target_user)
    TARGET_HOME="/home/$TARGET_USER"
    if [[ "$TARGET_USER" == "root" ]]; then
        TARGET_HOME="/root"
    fi
    
    # Update and install necessary packages
    apt-get update && apt-get install -y git uidmap fuse3 fuse-overlayfs python3-full python3-pip python3-venv

    mkdir -p "${TARGET_HOME}/.podman_temp"
    curl -sL $(curl -s https://api.github.com/repos/containers/podman/releases/latest | grep "browser_download_url.*podman-remote-static-linux_amd64.tar.gz" | cut -d '"' -f 4) -o "${TARGET_HOME}/.podman_temp/podman-remote-static-linux_amd64.tar.gz"
    tar --strip-components=2 -xzf "${TARGET_HOME}/.podman_temp/podman-remote-static-linux_amd64.tar.gz" -C /usr/local/bin bin/podman

    # Podman Compose
    python3 -m venv "${TARGET_HOME}/.venv/"
    "${TARGET_HOME}/.venv/bin/pip3" install --upgrade pip
    "${TARGET_HOME}/.venv/bin/pip3" install podman-compose

    # Add to PATH
    echo "export PATH=\$PATH:${TARGET_HOME}/.venv/bin" >>"${TARGET_HOME}/.bashrc"

    # Set permissions and aliases
    chmod +x "${TARGET_HOME}/.venv/bin/podman-compose"
    chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.venv"

    # Cleanup
    rm -rf "${TARGET_HOME}/.podman_temp"
}

install_podman_alvistack() {
    # Add Alvistack key and repository
    source /etc/os-release
    wget http://downloadcontent.opensuse.org/repositories/home:/alvistack/Debian_$VERSION_ID/Release.key -O alvistack_key
    cat alvistack_key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/alvistack.gpg >/dev/null

    echo "deb http://downloadcontent.opensuse.org/repositories/home:/alvistack/Debian_$VERSION_ID/ /" | sudo tee /etc/apt/sources.list.d/alvistack.list

    apt-get update && apt-get install -y podman podman-compose podman-netavark
}

# Function to setup podman configuration
setup_podman_config() {
    TARGET_USER=$(get_target_user)
    TARGET_HOME="/home/$TARGET_USER"
    if [[ "$TARGET_USER" == "root" ]]; then
        TARGET_HOME="/root"
    fi

    # Leave containers running after logout
    loginctl enable-linger "$TARGET_USER"

    # Enable privileged ports for Podman
    echo "net.ipv4.ip_unprivileged_port_start=80" | tee -a /etc/sysctl.d/podman-privileged-ports.conf
    sysctl --load /etc/sysctl.d/podman-privileged-ports.conf

    # Run as the target user
    sudo -u "$TARGET_USER" bash << EOF
# Create directories for Podman
mkdir -p "$TARGET_HOME/podman"
mkdir -p "$TARGET_HOME/.config/systemd/user"
mkdir -p "$TARGET_HOME/.config/containers"

# Add container registries
if [[ -f /etc/containers/registries.conf ]]; then
    cp /etc/containers/registries.conf "$TARGET_HOME/.config/containers/"
else
    touch "$TARGET_HOME/.config/containers/registries.conf"
fi

echo "
[registries.search]
registries = ['docker.io', 'ghcr.io', 'quay.io']" >> "$TARGET_HOME/.config/containers/registries.conf"

# Enable Podman socket
systemctl --user enable --now podman.socket 2>/dev/null || true

# Add alias for Podman
if ! grep -q "alias docker=podman" "$TARGET_HOME/.bashrc" 2>/dev/null; then
    echo "alias docker=podman" >> "$TARGET_HOME/.bashrc"
    echo "alias docker-compose=podman-compose" >> "$TARGET_HOME/.bashrc"
fi
EOF
}
