#!/bin/bash

# Function to configure SSH
configure_ssh() {
    local SSH_PORT="$1"
    local USER="$2"

    # Ask for authentication methods
    echo "Please select the authentication methods to accept:"
    echo "1) publickey"
    echo "2) password"
    echo "3) publickey,password"
    echo "4) keyboard-interactive"
    echo "5) publickey,keyboard-interactive"
    read -r AUTH_METHODS_CHOICE

    case $AUTH_METHODS_CHOICE in
    1) AUTH_METHODS="publickey" ;;
    2) AUTH_METHODS="password" ;;
    3) AUTH_METHODS="publickey,password" ;;
    4) AUTH_METHODS="keyboard-interactive" ;;
    5) AUTH_METHODS="publickey,keyboard-interactive" ;;
    *) AUTH_METHODS="publickey" ;; # Default to publickey
    esac

    # Ask whether to keep root login
    echo "Do you want to permit root login? (yes/no, default: no):"
    read -r PERMIT_ROOT_LOGIN
    PERMIT_ROOT_LOGIN=${PERMIT_ROOT_LOGIN:-no}

    # Backup original SSH config
    cp "$SSH_CONFIG" "${SSH_CONFIG}.bak"

    # Configure SSH
    sed -i "s/^#Port 22/Port $SSH_PORT/" "$SSH_CONFIG"
    sed -i "s/^#PermitRootLogin prohibit-password/PermitRootLogin $PERMIT_ROOT_LOGIN/" "$SSH_CONFIG"
    sed -i "s/^#PasswordAuthentication yes/PasswordAuthentication no/" "$SSH_CONFIG"
    sed -i "s/^#PubkeyAuthentication yes/PubkeyAuthentication yes/" "$SSH_CONFIG"

    # Add allowed user
    echo "AllowUsers $USER" >>"$SSH_CONFIG"

    # Set authentication methods
    echo "AuthenticationMethods $AUTH_METHODS" >>"$SSH_CONFIG"

    # Setup key authentication for the user
    mkdir -p /home/$USER/.ssh
    touch /home/$USER/.ssh/authorized_keys
    chmod 700 /home/$USER/.ssh
    chmod 600 /home/$USER/.ssh/authorized_keys
    chown -R $USER:$USER /home/$USER/.ssh

    if [[ "$AUTH_METHODS" == *"publickey"* ]]; then
        # Ask whether to create a keypair or provide one
        echo "Do you want to create a new SSH keypair? (yes/no, default: yes):"
        read -r CREATE_KEYPAIR
        CREATE_KEYPAIR=${CREATE_KEYPAIR:-yes}

        if [[ "$CREATE_KEYPAIR" == "yes" ]]; then
            ssh-keygen -t rsa -b 2048 -f /home/$USER/.ssh/id_rsa -N ""
            cat /home/$USER/.ssh/id_rsa.pub >>/home/$USER/.ssh/authorized_keys
            echo "SSH keypair created for user $USER."
            echo "Public Key:"
            cat /home/$USER/.ssh/id_rsa.pub
            echo "Private Key:"
            cat /home/$USER/.ssh/id_rsa
            echo "Please save the private key securely."
            echo "Press Enter to continue..."
            read -r
        else
            echo "Please paste your SSH public key (or leave empty to skip):"
            read -r SSH_KEY

            if [[ -n "$SSH_KEY" ]]; then
                echo "$SSH_KEY" >>/home/$USER/.ssh/authorized_keys
                echo "SSH key added for user $USER."
            else
                echo "No SSH key provided. You will need to add one later."
                # If no key provided, keep password authentication enabled for now
                sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/" "$SSH_CONFIG"
            fi
        fi
    fi

    # Show overview of selections made
    echo "Overview of SSH configuration:"
    echo "SSH Port: $SSH_PORT"
    echo "Allowed User: $USER"
    echo "Authentication Methods: $AUTH_METHODS"
    echo "Permit Root Login: $PERMIT_ROOT_LOGIN"

    # Provide options to the user
    while true; do
        echo "Please select an option:"
        echo "1) Write changes to config file"
        echo "2) Restart config"
        echo "3) Cancel configuration and return to server-manager.sh"
        read -r USER_CHOICE

        case $USER_CHOICE in
        1)
            # Write changes to config file
            echo "Do you want to restart SSH now? (yes/no, default: yes):"
            read -r RESTART_SSH
            RESTART_SSH=${RESTART_SSH:-yes}
            if [[ "$RESTART_SSH" == "yes" ]]; then
                systemctl restart ssh
                echo "SSH configured on port $SSH_PORT."
            else
                echo "SSH configuration changes saved but not restarted."
            fi
            break
            ;;
        2)
            # Restore original SSH config file and restart configuration script
            cp "${SSH_CONFIG}.bak" "$SSH_CONFIG"
            echo "Restarting SSH configuration..."
            configure_ssh "$SSH_PORT" "$USER"
            break
            ;;
        3)
            # Restore original SSH config and return to server-manager.sh
            cp "${SSH_CONFIG}.bak" "$SSH_CONFIG"
            echo "Configuration cancelled. Returning to server-manager.sh..."
            ./server-manager.sh
            break
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
        esac
    done
}
