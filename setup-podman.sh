#!/bin/bash

# Ensure script runs as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root or with sudo."
    exit 1
fi

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
        ;;
    3)
        echo "Using Alvistack repository..."
        install_podman_alvistack
        ;;
    *)
        echo "Using Github release..."
        install_podman_github
        ;;
    esac
}

# Install Podman from Github release
install_podman_github() {
    # Update and install necessary packages
    apt-get update && apt-get install -y git uidmap fuse3 fuse-overlayfs python3-full python3-pip python3-venv

    mkdir -p ${HOME}/.podman_temp
    curl -sL $(curl -s https://api.github.com/repos/containers/podman/releases/latest | grep "browser_download_url.*podman-remote-static-linux_amd64.tar.gz" | cut -d '"' -f 4) -o ${HOME}/.podman_temp/podman-remote-static-linux_amd64.tar.gz
    tar --strip-components=2 -xzf ${HOME}/.podman_temp/podman-remote-static-linux_amd64.tar.gz -C /usr/local/bin bin/podman

    # Podman Compose
    python3 -m venv ${HOME}/.venv/
    ${HOME}/.venv/bin/pip3 install --upgrade pip
    ${HOME}/.venv/pip3 --user install podman-compose

    # Add to PATH
    echo "export PATH=$PATH:${HOME}/.venv/bin" >>${HOME}/.bashrc
    source ${HOME}/.bashrc

    # Set permissions and aliases
    chmod +x ${HOME}/.venv/bin/podman
    chmod +x ${HOME}/.venv/bin/podman-compose
    chown -R {$USER}:{$USER} ${HOME}/.venv

    # Cleanup
    rm -rf ${HOME}/.podman_temp
}

install_podman_alvistack() {
    # Add Alvistack key and repository
    source /etc/os-release
    wget http://downloadcontent.opensuse.org/repositories/home:/alvistack/Debian_$VERSION_ID/Release.key -O alvistack_key
    cat alvistack_key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/alvistack.gpg >/dev/null

    echo "deb http://downloadcontent.opensuse.org/repositories/home:/alvistack/Debian_$VERSION_ID/ /" | sudo tee /etc/apt/sources.list.d/alvistack.list

    apt-get update && apt-get install -y podman podman-compose podman-netavark
}

# Leave containers running after logout
sudo loginctl enable-linger ${USER}

# Enable priviliged ports for Podman
echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee -a /etc/sysctl.d/podman-privileged-ports.conf
sudo sysctl --load /etc/sysctl.d/podman-privileged-ports.conf

# Create directories for Podman
mkdir -p ${HOME}/podman
mkdir -p ${HOME}/.config/systemd/user
mkdir -p ${HOME}/.config/containers

# Add container registries
cp /etc/containers/registries.conf ${HOME}/.config/containers/
echo "
[registries.search]
registries = ['docker.io', 'ghcr.io', 'quay.io']" | tee -a ${HOME}/.config/containers/registries.conf

# Enable Podman socket
systemctl --user enable --now podman.socket

# Add alias for Podman
echo "alias docker=podman" | tee -a ${HOME}/.bashrc
echo "alias docker-compose=podman-compose" | tee -a ${HOME}/.bashrc
