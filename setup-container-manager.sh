#!/bin/bash

# Function to choose container UI
choose_container_ui() {
    local CONTAINER_ENGINE="$1"

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
    2)
        echo "Installing Cockpit..."
        install_cockpit
        ;;
    3)
        if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
            echo "Installing Komodo..."
            install_komodo
        else
            echo "Komodo requires Docker. Installing Portainer instead..."
            install_portainer
        fi
        ;;
    4)
        echo "Installing Yacht..."
        install_yacht
        ;;
    5)
        echo "Installing dweebui..."
        install_dweebui
        ;;
    6)
        echo "Installing Dockge..."
        install_dockge
        ;;
    7)
        echo "Skipping container UI installation."
        ;;
    *)
        echo "Installing Portainer..."
        install_portainer
        ;;
    esac
}
