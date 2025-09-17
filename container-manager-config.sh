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
    local TARGET_USER="${2:-${SUDO_USER:-$USER}}"

    local run_cmd=""
    case "$CONTAINER_ENGINE" in
    docker)
        docker volume create portainer_data || true
        docker run -d -p 9443:9443 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data --name=portainer --restart=always portainer/portainer-ce:latest
        ;;
    docker-rootless)
        _run_as_user "$TARGET_USER" "docker volume create portainer_data || true"
        _run_as_user "$TARGET_USER" "docker run -d -p 9443:9443 -v \$XDG_RUNTIME_DIR/docker.sock:/var/run/docker.sock -v portainer_data:/data --name=portainer --restart=always portainer/portainer-ce:latest"
        ;;
    podman|podman-rootless)
        _run_as_user "$TARGET_USER" "podman volume create portainer_data || true"
        _run_as_user "$TARGET_USER" "podman run -d -p 9443:9443 --name portainer -v \$XDG_RUNTIME_DIR/podman/podman.sock:/var/run/docker.sock -v portainer_data:/data --restart=always --privileged portainer/portainer-ce:latest"
        ;;
    *) echo "Invalid container engine." ;;
    esac
}

# Install Komodo
install_komodo() {
    local CONTAINER_ENGINE="$1"
    echo "Komodo installation not implemented yet."
}

# Install Dockge
install_dockge() {
    local CONTAINER_ENGINE="$1"
    echo "Dockge installation not implemented yet."
}

# Install DweebUI
install_dweebui() {
    local CONTAINER_ENGINE="$1"
    echo "DweebUI installation not implemented yet."
}

# Install Cockpit
install_cockpit() {
    local CONTAINER_ENGINE="$1"; local TARGET_USER="${2:-${SUDO_USER:-$USER}}"
    apt-get update && apt-get install -y cockpit cockpit-podman || true
    systemctl enable --now cockpit.socket
    echo "Cockpit installed. Access: https://<server>:9090"
}

# Install Yacht
install_yacht() {
    local CONTAINER_ENGINE="$1"
    local TARGET_USER="${2:-${SUDO_USER:-$USER}}"

    case "$CONTAINER_ENGINE" in
    docker)
        docker volume create yacht_data || true
        docker run -d -p 8000:8000 -v /var/run/docker.sock:/var/run/docker.sock -v yacht_data:/config --name=yacht --restart=always selfhostedpro/yacht:latest
        ;;
    docker-rootless)
        _run_as_user "$TARGET_USER" "docker volume create yacht_data || true"
        _run_as_user "$TARGET_USER" "docker run -d -p 8000:8000 -v \$XDG_RUNTIME_DIR/docker.sock:/var/run/docker.sock -v yacht_data:/config --name=yacht --restart=always selfhostedpro/yacht:latest"
        ;;
    podman|podman-rootless)
        _run_as_user "$TARGET_USER" "podman volume create yacht_data || true"
        _run_as_user "$TARGET_USER" "podman run -d -p 8000:8000 --name yacht -v \$XDG_RUNTIME_DIR/podman/podman.sock:/var/run/docker.sock -v yacht_data:/config --restart=always --privileged selfhostedpro/yacht:latest"
        ;;
    *)
        echo "Invalid container engine."
        ;;
    esac
}

# Prompt-only: return selected manager keyword
choose_container_manager_prompt() {
    local choice
    echo "Choose container management UI:"
    echo "1) Portainer"
    echo "2) Cockpit"
    echo "3) Komodo"
    echo "4) Yacht"
    echo "5) dweebui"
    echo "6) Dockge"
    echo "7) None"
    read -r -p "Select option (1-7) [1]: " choice
    case "$choice" in
        2) echo "cockpit" ;;
        3) echo "komodo" ;;
        4) echo "yacht" ;;
        5) echo "dweebui" ;;
        6) echo "dockge" ;;
        7) echo "none" ;;
        *) echo "portainer" ;;
    esac
}

# Helper to run commands as target user (for rootless engines)
_run_as_user() {
    local target_user="$1"; shift
    sudo -iu "$target_user" bash -lc "$*"
}

# Non-interactive installer
install_container_manager() {
    local manager="$1"
    local engine="$2"
    local user="$3"
    case "$manager" in
        portainer) install_portainer "$engine" "$user" ;;
        yacht)     install_yacht "$engine" "$user" ;;
        cockpit)   install_cockpit "$engine" "$user" ;;
        komodo)    echo "Komodo installer not implemented; skipping." ;;
        dweebui)   echo "DweebUI installer not implemented; skipping." ;;
        dockge)    echo "Dockge installer not implemented; skipping." ;;
        none|"" ) echo "Skipping container UI installation." ;;
        *)         echo "Unknown manager '$manager' - skipping." ;;
    esac
}
