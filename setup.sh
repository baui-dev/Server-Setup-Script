#!/bin/bash

# Comprehensive server setup script that:
# - Sets up a fresh Debian server
# - Creates a sudo user
# - Installs Docker, Portainer, and cloud storage mounts
# - Implements Docker-compatible firewall (iptables)
# - Sets up security auditing and reporting
# - Configures SSH security

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Variables
HOME_DIR=""
LOG_DIR="/var/log/security-audit"
SSH_CONFIG="/etc/ssh/sshd_config"
CRON_JOB="/etc/cron.d/security-audit"
MOTD_FILE="/etc/motd"
SEVERE_LOG="/var/log/security-audit/severe.log"

# Source required scripts
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/network-setup.sh"
source "$DIR/security-setup.sh"
source "$DIR/container-setup.sh"
source "$DIR/rclone-setup.sh"

# Update and upgrade the system first
echo "Updating system packages..."
apt update && apt dist-upgrade -y

# Install essential packages
apt install -y sudo curl wget apt-transport-https gnupg2 software-properties-common \
    ca-certificates lsb-release fail2ban logwatch lynis

# Function to prompt for username and create user
create_sudo_user() {
    # Prompt for new username
    read -p "Enter new username: " NEW_USER
    while [[ -z "$NEW_USER" || "$NEW_USER" == "root" ]]; do
        echo "Invalid username. Please try again."
        read -p "Enter new username: " NEW_USER
    done

    # Check if user already exists
    if id "$NEW_USER" &>/dev/null; then
        echo "User $NEW_USER already exists."
        read -p "Do you want to set a new password for $NEW_USER? (y/n): " RESET_PASS
        if [[ "$RESET_PASS" == "y" || "$RESET_PASS" == "Y" ]]; then
            passwd "$NEW_USER"
        fi
    else
        # Create new user
        useradd -m -s /bin/bash "$NEW_USER"
        passwd "$NEW_USER"

        # Install sudo if not present and add user to sudo group
        if ! command -v sudo &>/dev/null; then
            apt-get update && apt-get install -y sudo
        fi

        usermod -aG sudo "$NEW_USER"
        echo "$NEW_USER ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/$NEW_USER
        chmod 0440 /etc/sudoers.d/$NEW_USER
        echo "User $NEW_USER created with sudo privileges."
    fi

    # Return the username
    echo "$NEW_USER"
}

# Main execution flow
echo "Starting server setup..."

# Create sudo user
USER=$(create_sudo_user)
echo "Using user: $USER"

# Configure SSH security
SSH_PORT=$(prompt_ssh_port)
configure_ssh "$SSH_PORT" "$USER"

# Setup firewall
echo "Setting up firewall..."
setup_firewall "$SSH_PORT"

# Setup security audit
echo "Setting up security audit..."
setup_security_audit "$USER" "$SSH_PORT"

# Choose and install container manager
CONTAINER_MANAGER=$(choose_container_manager "$USER")

# Choose and install container UI
choose_container_ui "$CONTAINER_MANAGER"

# Setup rclone
echo "Setting up rclone..."
setup_rclone "$USER"

# Enable and start rclone mounts
echo "Enabling rclone automounts..."
systemctl enable onedrive_automount.service
systemctl enable mega_automount.service
systemctl start onedrive_automount.service
systemctl start mega_automount.service

# Run security audit immediately
/usr/local/bin/security-audit.sh

# Finished
echo "Setup complete!"
echo "Your system has been configured with:"
echo "- User: $USER with sudo privileges"
echo "- SSH on port $SSH_PORT (port 22 kept open but all attempts are logged)"
echo "- Docker-compatible firewall (iptables)"
echo "- Security audit running hourly"
echo "- Container system and management UI installed"
echo "- rclone configured for media streaming"
echo "Please reconnect to your server using: ssh $USER@your-server-ip -p $SSH_PORT"

# Prompt for reboot
read -p "Reboot now? (y/n): " REBOOT
if [[ "$REBOOT" == "y" || "$REBOOT" == "Y" ]]; then
    reboot
fi
