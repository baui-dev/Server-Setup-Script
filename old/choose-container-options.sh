# Function to choose container manager
choose_container_manager() {
    local USER="$1"
    
    echo "Choose container manager:"
    echo "1. Docker (Standard)"
    echo "2. Docker (Rootless)"
    echo "3. Podman (Standard)"
    echo "4. Podman (Rootless)"
    read -p "Select option (1/4): " CONTAINER_OPTION
    
    if [[ "$CONTAINER_OPTION" == "2" ]]; then
        echo "Installing Podman..."
        install_podman "$USER"
        echo "podman"
    else
        echo "Installing Docker..."
        install_docker "$USER"
        echo "docker"
    fi
}

# Function to choose Container Management UI or AiO
choose_container_manager() {
    local USER="$1"
    
    echo "Choose container manager or AiO:"
    echo "1. Container Manager"
    echo "2. AiO (All-in-One)"
    read -p "Select option (1/2): " CONTAINER_OPTION
    
    if [[ "$CONTAINER_OPTION" == "2" ]]; then
        choose_aio_ui "$USER"
    else
        choose_container_ui "$USER"
    fi
}

# Function to choose container UI
choose_container_ui() {
    local MANAGER="$1"
    
    echo "Choose container management UI:"
    echo "1. Portainer"
    echo "2. Cockpit"
    echo "3. Komodo"
    echo "4. Yacht"
    echo "5. dweebui"
    echo "6. Dockge"
    echo "7. None"
    read -p "Select option (1-7): " UI_OPTION
    
    case "$UI_OPTION" in
        2)
            echo "Installing Cockpit..."
            install_cockpit
            ;;
        3)
            if [[ "$MANAGER" == "docker" ]]; then
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

# Function to choose AiO UI
choose_aio_ui() {
    local USER="$1"
    
    echo "Choose AiO UI:"
    echo "1. CosmosUI"
    echo "2. CasaOS"
    echo "3. Runtipi"
    echo "4. Umbrel"
    echo "5. DockSTARTer"
    echo "6. Coolify"
    echo "7. TrueNas"
    echo "8. Unraid"
    echo "9. OpenMediaVault"
    read -p "Select option (1-7): " UI_OPTION
    
    case "$UI_OPTION" in
        2) 


#Yunohost, HomelabOS, Ethibox, Elistio, Coop Cloud, Sandstorm, Caprover, Dokku, Freedombox, Easypanel, Cloudron, HexOS, PikaPods, (Cloudbox, Cloudcmd, CloudC2, Cloud9, Cloudify, ) 
# https://forum.cloudron.io/topic/10000/a-list-of-cloudron-like-services-competitors