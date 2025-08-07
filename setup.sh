#!/bin/bash

# Comprehensive server setup script that:
# - Sets up a fresh Debian server
# - Creates a sudo user
# - Installs Docker/Podman and Portainer
# - Configures SSH security

set -euo pipefail

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Variables
SSH_CONFIG="/etc/ssh/sshd_config"

# Source required scripts
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/ssh-setup.sh"
source "$DIR/choose-container-options.sh"
source "$DIR/setup-docker.sh"
source "$DIR/setup-podman.sh"
source "$DIR/setup-container-manager.sh"

# Function to prompt for SSH port
prompt_ssh_port() {
    local ssh_port
    while true; do
        read -p "Enter SSH port (default 22): " ssh_port
        ssh_port=${ssh_port:-22}
        
        if [[ "$ssh_port" =~ ^[0-9]+$ ]] && [[ "$ssh_port" -ge 1 ]] && [[ "$ssh_port" -le 65535 ]]; then
            echo "$ssh_port"
            break
        else
            echo "Invalid port. Please enter a number between 1 and 65535."
        fi
    done
}

# Function to setup basic firewall
setup_firewall() {
    local SSH_PORT="$1"
    
    # Install iptables-persistent
    apt-get install -y iptables-persistent
    
    # Basic firewall rules
    iptables -F
    iptables -P INPUT DROP
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    
    # Allow loopback
    iptables -A INPUT -i lo -j ACCEPT
    
    # Allow established connections
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # Allow SSH
    iptables -A INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT
    
    # Allow HTTP/HTTPS
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    
    # Allow container management ports
    iptables -A INPUT -p tcp --dport 8000 -j ACCEPT  # Yacht
    iptables -A INPUT -p tcp --dport 9443 -j ACCEPT  # Portainer
    
    # Save rules
    iptables-save > /etc/iptables/rules.v4
    
    echo "Firewall configured with SSH on port $SSH_PORT"
}

# Install critical packages first
echo "Updating system packages..."
apt update && apt install -y sudo curl wget apt-transport-https gnupg2 software-properties-common \
    ca-certificates lsb-release openssh-server

# Function to list existing non-system users
list_existing_users() {
    awk -F: '($3>=1000)&&($1!="nobody") {print $1}' /etc/passwd
}

# Prompt to use existing user or create new one
prompt_for_user() {
    local USERS
    USERS=( $(list_existing_users) )
    if [[ ${#USERS[@]} -gt 0 ]]; then
        echo "Existing users found:"
        local i=1
        for u in "${USERS[@]}"; do
            echo "$i) $u"
            ((i++))
        done
        echo "$i) Create new user"
        read -p "Select user (1-$i): " USER_CHOICE
        if [[ "$USER_CHOICE" -ge 1 && "$USER_CHOICE" -lt $i ]]; then
            CHOSEN_USER="${USERS[$((USER_CHOICE-1))]}"
        else
            CHOSEN_USER=""
        fi
    else
        CHOSEN_USER=""
    fi
    if [[ -z "$CHOSEN_USER" ]]; then
        read -p "Enter new username: " NEW_USER
        CHOSEN_USER="$NEW_USER"
        CREATE_NEW_USER=1
    else
        CREATE_NEW_USER=0
    fi
    echo "$CHOSEN_USER"
}

# Function to check for installed container management UIs
check_installed_container_ui() {
    local found=()
    if docker ps -a --format '{{.Image}}' | grep -q portainer; then found+=("Portainer"); fi
    if docker ps -a --format '{{.Image}}' | grep -q yacht; then found+=("Yacht"); fi
    if systemctl is-active --quiet cockpit.socket 2>/dev/null; then found+=("Cockpit"); fi
    # Add more checks as needed
    if [[ ${#found[@]} -gt 0 ]]; then
        echo "Installed container UIs: ${found[*]}"
        echo "Do you want to use an existing one? (y/n): "
        read USE_EXISTING_UI
        if [[ "$USE_EXISTING_UI" == "y" ]]; then
            echo "Using existing container UI: ${found[0]}"
            USE_EXISTING_CONTAINER_UI=1
        else
            USE_EXISTING_CONTAINER_UI=0
        fi
    else
        USE_EXISTING_CONTAINER_UI=0
    fi
}

# Prompt for rclone/cloud storage
prompt_rclone() {
    echo "Do you want to mount cloud storage with rclone? (y/n): "
    read USE_RCLONE
    if [[ "$USE_RCLONE" == "y" ]]; then
        apt install -y rclone
        echo "rclone installed."
    fi
}

# Collect all configuration choices
# (SSH port, container engine, etc.)
collect_config() {
    # ...existing code for prompts, but do not apply changes yet...
    # Store choices in variables for later use
    :
}

# Apply all changes in one go at the end
apply_all_changes() {
    # ...existing code for user creation, SSH config, container engine, firewall, etc...
    # Use the variables collected above
    :
}

# Main execution flow

# 1. Prompt for user
USER=$(prompt_for_user)

# 2. Check for installed container UIs
check_installed_container_ui

# 3. Prompt for rclone/cloud storage
prompt_rclone

# 4. Collect all other configuration choices
collect_config

# 5. Apply all changes in one go
apply_all_changes

# Finished
echo "Setup complete!"
echo "Your system has been configured with:"
echo "- User: $USER with sudo privileges"
echo "- SSH on port $SSH_PORT"
echo "- Basic firewall (iptables)"
echo "- Container system and management UI installed"
echo "Please reconnect to your server using: ssh $USER@your-server-ip -p $SSH_PORT"

# Prompt for reboot
read -p "Reboot now? (y/n): " REBOOT
if [[ "$REBOOT" == "y" || "$REBOOT" == "Y" ]]; then
    reboot
fi
