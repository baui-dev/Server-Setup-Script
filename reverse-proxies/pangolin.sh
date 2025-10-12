#!/bin/bash

# Function to get container runtime
get_container_runtime() {
    echo "Choose container runtime:"
    echo "1) Docker"
    echo "2) Podman"
    read -r -p "Select option (1-2) [1]: " choice
    case "$choice" in
        2) echo "podman" ;;
        *) echo "docker" ;;
    esac
}

# Install Pangolin reverse proxy according to selected container runtime
install_pangolin() {
    local runtime="$1"
    if [[ "$runtime" == "podman" ]]; then
        install_pangolin_podman
    else
        install_pangolin_docker
    fi
}
    echo "Installing Pangolin reverse proxy with Docker..."
    # Pull the Pangolin image
    docker pull ghcr.io/evertramos/pangolin:latest
    # Create and run the Pangolin container
    docker run -d --name pangolin \
        -p 80:80 -p 443:443 \
        -v /etc/pangolin:/app/data \
        --restart unless-stopped \
        ghcr.io/evertramos/pangolin:latest
    echo "Pangolin reverse proxy installed and running with Docker."


install_pangolin_podman() {
    echo "Installing Pangolin reverse proxy with Podman..."
    # Pull the Pangolin image
    podman pull ghcr.io/evertramos/pangolin:latest
    # Create and run the Pangolin container
    podman run -d --name pangolin \
        -p 80:80 -p 443:443 \
        -v /etc/pangolin:/app/data \
        --restart unless-stopped \
        ghcr.io/evertramos/pangolin:latest
    echo "Pangolin reverse proxy installed and running with Podman."
}