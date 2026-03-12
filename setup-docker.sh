#!/bin/bash

# Ensure script runs as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root or with sudo."
    exit 1
fi

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
    # Ensure dependencies are installed
    sudo apt update && sudo apt install -y uidmap dbus-user-session iptables slirp4netns dbus-user-session

    # Install Docker binaries
    curl -fsSL https://get.docker.com/rootless | sh

    # Add Docker bin path to .bashrc (or .zshrc)
    export PATH=$HOME/bin:$PATH
    echo 'export PATH=$HOME/bin:$PATH' >>~/.bashrc
    echo 'export PATH=$HOME/bin:$PATH' >>~/.zshrc 2>/dev/null
    echo 'export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock' >>~/.bashrc
    echo 'export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock' >>~/.zshrc 2>/dev/null

    # Enable the rootless Docker service
    systemctl --user start docker
    systemctl --user enable --now docker

    # Ensure the service starts on boot
    sudo loginctl enable-linger $(whoami)

    echo "Docker (rootless) installed successfully!"
    echo "To verify, run: systemctl --user status docker"
}
