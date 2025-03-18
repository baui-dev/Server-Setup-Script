#!/bin/bash

# Function to configure SSH
configure_ssh() {
    local SSH_PORT="$1"
    local USER="$2"

    # Backup original SSH config
    cp "$SSH_CONFIG" "${SSH_CONFIG}.bak"

    # Configure SSH
    sed -i "s/^#Port 22/Port $SSH_PORT/" "$SSH_CONFIG"
    sed -i "s/^#PermitRootLogin prohibit-password/PermitRootLogin no/" "$SSH_CONFIG"
    sed -i "s/^#PasswordAuthentication yes/PasswordAuthentication no/" "$SSH_CONFIG"
    sed -i "s/^#PubkeyAuthentication yes/PubkeyAuthentication yes/" "$SSH_CONFIG"

    # Add our user to allowed users
    echo "AllowUsers $USER" >>"$SSH_CONFIG"

    # Setup key authentication for our user
    mkdir -p /home/$USER/.ssh
    touch /home/$USER/.ssh/authorized_keys
    chmod 700 /home/$USER/.ssh
    chmod 600 /home/$USER/.ssh/authorized_keys
    chown -R $USER:$USER /home/$USER/.ssh

    # Ask for SSH public key
    echo "Please paste your SSH public key (or leave empty to skip):"
    read -r SSH_KEY

    if [[ -n "$SSH_KEY" ]]; then
        echo "$SSH_KEY" >>/home/$USER/.ssh/authorized_keys
        echo "SSH key added."
    else
        echo "No SSH key provided. You will need to add one later."
        # If no key provided, keep password authentication enabled for now
        sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/" "$SSH_CONFIG"
    fi

    # Restart SSH service
    systemctl restart ssh

    echo "SSH configured on port $SSH_PORT."
    return "$SSH_PORT"
}
