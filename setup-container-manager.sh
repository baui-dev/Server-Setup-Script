#!/bin/bash

# Function to choose container manager
choose_container_manager() {
    local CONTAINER_ENGINE="$1"
    local SOCKET="$2"

    while true; do
        echo "Choose container manager:"
        echo "1. Portainer"
        echo "2. Cockpit"
        echo "3. Komodo"
        echo "4. Yacht"
        echo "5. dweebui"
        echo "6. Dockge"
        echo "7. None"
        read -p "Select option (1-7): " CONTAINER_MANAGER

        case "$CONTAINER_MANAGER" in
        1)
            echo "Installing Portainer..."
            install_portainer "$CONTAINER_ENGINE"
            break
            ;;
        2)
            echo "Installing Cockpit..."
            install_cockpit "$CONTAINER_ENGINE"
            break
            ;;
        3)
            if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
                echo "Installing Komodo..."
                install_komodo "$CONTAINER_ENGINE"
            else
                echo "Komodo requires Docker. Installing Portainer instead..."
                install_portainer "$CONTAINER_ENGINE"
            fi
            break
            ;;
        4)
            echo "Installing Yacht..."
            install_yacht "$CONTAINER_ENGINE"
            break
            ;;
        5)
            echo "Installing dweebui..."
            install_dweebui "$CONTAINER_ENGINE"
            break
            ;;
        6)
            echo "Installing Dockge..."
            install_dockge "$CONTAINER_ENGINE"
            break
            ;;
        7)
            echo "Skipping container UI installation."
            break
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
        esac
    done
}

# Install Portainer
install_portainer() {
    local CONTAINER_ENGINE="$1"

    while true; do
        echo "Choose Portainer edition:"
        echo "1. Community Edition"
        echo "2. Business Edition"
        echo "3. Back"
        read -p "Select option (1-3): " PORTAINER_EDITION

        case "$PORTAINER_EDITION" in
        1)
            PORTAINER_IMAGE="portainer/portainer-ce:latest"
            break
            ;;
        2)
            PORTAINER_IMAGE="portainer/portainer-ee:latest"
            break
            ;;
        3)
            choose_container_manager "$CONTAINER_ENGINE"
            return
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
        esac
    done

    case "$CONTAINER_ENGINE" in
    docker)
        docker volume create portainer_data
        docker run -d -p 9443:9443 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data --name=portainer --restart=always $PORTAINER_IMAGE
        ;;
    docker-rootless)
        docker volume create portainer_data
        docker run -d -p 9443:9443 -v /run/user/1000/docker.sock:/var/run/docker.sock -v portainer_data:/data --name=portainer --restart=always $PORTAINER_IMAGE
        ;;
    podman)
        podman volume create portainer_data
        podman run -d -p 9443:9443 --name portainer -v /run/user/1000/podman/podman.sock:/var/run/docker.sock -v portainer_data:/data --restart=always --privileged $PORTAINER_IMAGE
        ;;
    podman-rootless)
        podman volume create portainer_data
        podman run -d -p 9443:9443 --name portainer -v /run/user/1000/podman/podman.sock:/var/run/docker.sock -v portainer_data:/data --restart=always --privileged $PORTAINER_IMAGE
        ;;
    *)
        echo "Invalid container engine."
        ;;
    esac
}

# Install Komodo
install_komodo() {
    local CONTAINER_ENGINE="$1"

}

# Install Dockge
install_dockge() {
    local CONTAINER_ENGINE="$1"

}

# Install DweebUI
install_dweebui() {
    local CONTAINER_ENGINE="$1"

}

# Install Yacht
install_yacht() {
    local CONTAINER_ENGINE="$1"

    case "$CONTAINER_ENGINE" in
    docker)
        docker volume create yacht_data
        docker run -d -p 8000:8000 -v /var/run/docker.sock:/var/run/docker.sock -v yacht_data:/config --name=yacht --restart=always selfhostedpro/yacht:latest
        ;;
    docker-rootless)
        docker volume create yacht_data
        docker run -d -p 8000:8000 -v /run/user/1000/docker.sock:/var/run/docker.sock -v yacht_data:/config --name=yacht --restart=always selfhostedpro/yacht:latest
        ;;
    podman)
        podman volume create yacht_data
        podman run -d -p 8000:8000 --name yacht -v /run/user/1000/podman/podman.sock -v yacht_data:/config --restart=always --privileged selfhostedpro/yacht:latest
        ;;
    podman-rootless)
        podman volume create yacht_data
        podman run -d -p 8000:8000 --name yacht -v /run/user/1000/podman/podman.sock -v yacht_data:/config --restart=always --privileged selfhostedpro/yacht:latest
        ;;
    *)
        echo "Invalid container engine."
        ;;
    esac
}
