#!/bin/bash

# Function to setup docker
setup_docker() {
    local USER="$1"
    local MODE="$2"
    
    if [[ "$MODE" == "rootless" ]]; then
        install_docker_rootless
    else
        install_docker
        usermod -aG docker "$USER"
    fi
}

# Function to setup podman
setup_podman() {
    local USER="$1"
    local MODE="$2"
    
    choose_podman_source
}

# Function to choose container manager
choose_container_engine() {
    local USER="$1"

    echo "Choose container manager:"
    echo "1. Docker (Standard)"
    echo "2. Docker (Rootless)"
    echo "3. Podman (Standard)"
    echo "4. Podman (Rootless)"
    read -p "Select option (1/4): " CONTAINER_ENGINE

    case "$CONTAINER_ENGINE" in
    2)
        echo "Installing Docker in rootless mode..."
        setup_docker "$USER" "rootless"
        echo "docker-rootless"
        ;;
    3)
        echo "Installing Podman..."
        setup_podman "$USER" "standard"
        echo "podman"
        ;;
    4)
        echo "Installing Podman in rootless mode..."
        setup_podman "$USER" "rootless"
        echo "podman-rootless"
        ;;
    *)
        echo "Installing Docker..."
        setup_docker "$USER" "standard"
        echo "docker"
        ;;
    esac

}

# Function to choose Container Manager or AiO (All-in-One) or None
choose_management_options() {
    local USER="$1"

    echo "Choose container options:"
    echo "1. Container Manager"
    echo "2. AiO Manager (All-in-One)"
    echo "3. None"
    echo "4. Back"
    read -p "Select option (1/4): " CONTAINER_OPTIONS

    case "$CONTAINER_OPTIONS" in
    2)
        choose_aio_manager "$USER"
        ;;
    3)
        echo "Skipping container manager installation."
        ;;
    4)
        choose_container_engine "$USER"
        ;;
    *)
        choose_container_manager "$USER"
        ;;
    esac
}

# Function to choose container manager
choose_container_manager() {
    local CONTAINER_ENGINE="$1"

    echo "Choose container management UI:"
    echo "1. Portainer"
    echo "2. Cockpit"
    echo "3. Komodo"
    echo "4. Yacht"
    echo "5. dweebui"
    echo "6. Dockge"
    echo "7. None"
    echo "8. Back"
    read -p "Select option (1-7): " CONTAINER_MANAGER

    case "$CONTAINER_MANAGER" in
    2)
        echo "Installing Cockpit..."
        install_cockpit "$CONTAINER_ENGINE"
        ;;
    3)
        if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
            echo "Installing Komodo..."
            install_komodo "$CONTAINER_ENGINE"
        else
            echo "Komodo requires Docker. Installing Portainer instead..."
            install_portainer "$CONTAINER_ENGINE"
        fi
        ;;
    4)
        echo "Installing Yacht..."
        install_yacht "$CONTAINER_ENGINE"
        ;;
    5)
        echo "Installing dweebui..."
        install_dweebui "$CONTAINER_ENGINE"
        ;;
    6)
        echo "Installing Dockge..."
        install_dockge "$CONTAINER_ENGINE"
        ;;
    7)
        echo "Skipping container UI installation."
        ;;
    8)
        choose_management_options "$USER"
        ;;
    *)
        echo "Installing Portainer..."
        install_portainer "$CONTAINER_ENGINE"
        ;;
    esac
}

# Function to choose AiO Suite
choose_aio_manager() {
    local USER="$1"

    echo "Choose an AiO Manager:"
    echo "1. CosmosUI"
    echo "2. CasaOS"
    echo "3. Runtipi"
    echo "4. Umbrel"
    echo "5. DockSTARTer"
    echo "6. Coolify"
    echo "7. TrueNas"
    echo "8. Unraid"
    echo "9. OpenMediaVault"
    echo "10. None"
    echo "11. Back"
    read -p "Select option (1-1): " AIO_MANAGER

    case "$AIO_MANAGER" in
    2)
        echo "Installing CasaOS..."
        install_casaos
        ;;
    3)
        echo "Installing Runtipi..."
        install_runtipi
        ;;
    4)
        echo "Installing Umbrel..."
        install_umbrel
        ;;
    5)
        echo "Installing DockSTARTer..."
        install_dockstarter
        ;;
    6)
        echo "Installing Coolify..."
        install_coolify
        ;;
    7)
        echo "Installing TrueNas..."
        install_truenas
        ;;
    8)
        echo "Installing Unraid..."
        install_unraid
        ;;
    9)
        echo "Installing OpenMediaVault..."
        install_openmediavault
        ;;
    10)
        echo "Skipping AiO installation."
        ;;
    11)
        choose_management_options "$USER"
        ;;
    *)
        echo "Installing CosmosUI..."
        install_cosmosui
        ;;
    esac
}

#Yunohost, HomelabOS, Ethibox, Elistio, Coop Cloud, Sandstorm, Caprover, Dokku, Freedombox, Easypanel, Cloudron, HexOS, PikaPods, (Cloudbox, Cloudcmd, CloudC2, Cloud9, Cloudify, )
# https://forum.cloudron.io/topic/10000/a-list-of-cloudron-like-services-competitors

# Placeholder install functions for AiO managers
install_cosmosui() {
    echo "CosmosUI installation not implemented yet."
}

install_casaos() {
    echo "CasaOS installation not implemented yet."
}

install_runtipi() {
    echo "Runtipi installation not implemented yet."
}

install_umbrel() {
    echo "Umbrel installation not implemented yet."
}

install_dockstarter() {
    echo "DockSTARTer installation not implemented yet."
}

install_coolify() {
    echo "Coolify installation not implemented yet."
}

install_truenas() {
    echo "TrueNas installation not implemented yet."
}

install_unraid() {
    echo "Unraid installation not implemented yet."
}

install_openmediavault() {
    echo "OpenMediaVault installation not implemented yet."
}
