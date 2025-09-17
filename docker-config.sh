#!/bin/bash

install_docker() {
    # Update and install necessary packages
    apt-get update && apt-get install -y ca-certificates curl gnupg

    # Create keyring directory and download Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null

    # Update and install Docker
    apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Enable and start Docker
    systemctl enable docker
    systemctl start docker

    echo "Docker installed successfully."
}

# Install Docker Rootless
install_docker_rootless() {
    local TARGET_USER="${1:-${SUDO_USER:-$USER}}"
    local TARGET_HOME
    if [[ "$TARGET_USER" == "root" ]]; then
        echo "Rootless Docker cannot be installed for root user." >&2
        return 1
    fi
    TARGET_HOME="/home/$TARGET_USER"

    # System deps
    apt-get update && apt-get install -y uidmap dbus-user-session iptables slirp4netns curl

    # Enable lingering so user services can run without login
    loginctl enable-linger "$TARGET_USER" || true

    # Run the official rootless installer as the target user
    sudo -iu "$TARGET_USER" bash -lc '
        set -e
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
        export PATH="$HOME/bin:$PATH"
        curl -fsSL https://get.docker.com/rootless | sh
        echo "export PATH=\$HOME/bin:\$PATH" >> "$HOME/.bashrc"
        echo "export DOCKER_HOST=unix://\$XDG_RUNTIME_DIR/docker.sock" >> "$HOME/.bashrc"
        mkdir -p "$HOME/.config/systemd/user"
        systemctl --user enable --now docker.service || true
    '

    echo "Docker (rootless) installed for user $TARGET_USER."
    echo "Verify with: sudo -iu $TARGET_USER systemctl --user status docker"
}
