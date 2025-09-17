#!/bin/bash

# Define SSH config file path
SSH_CONFIG="/etc/ssh/sshd_config"

# Function to configure SSH
configure_ssh() {
    local SSH_PORT="$1"
    local USER="$2"
    
    # Validate inputs
    if [[ -z "$SSH_PORT" || -z "$USER" ]]; then
        echo "Error: SSH port and user must be provided"
        return 1
    fi

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

    # Determine user home directory
    local USER_HOME
    if [[ "$USER" == "root" ]]; then
        USER_HOME="/root"
    else
        USER_HOME="/home/$USER"
    fi

    # Configure SSH - handle both commented and uncommented lines
    sed -i "s/^#Port 22/Port $SSH_PORT/" "$SSH_CONFIG"
    sed -i "s/^Port .*/Port $SSH_PORT/" "$SSH_CONFIG"
    sed -i "s/^#PermitRootLogin prohibit-password/PermitRootLogin $PERMIT_ROOT_LOGIN/" "$SSH_CONFIG"
    sed -i "s/^PermitRootLogin .*/PermitRootLogin $PERMIT_ROOT_LOGIN/" "$SSH_CONFIG"
    
    # Set password authentication based on selected methods
    if [[ "$AUTH_METHODS" == *"password"* ]]; then
        sed -i "s/^#PasswordAuthentication .*/PasswordAuthentication yes/" "$SSH_CONFIG"
        sed -i "s/^PasswordAuthentication .*/PasswordAuthentication yes/" "$SSH_CONFIG"
    else
        sed -i "s/^#PasswordAuthentication .*/PasswordAuthentication no/" "$SSH_CONFIG"
        sed -i "s/^PasswordAuthentication .*/PasswordAuthentication no/" "$SSH_CONFIG"
    fi
    
    sed -i "s/^#PubkeyAuthentication yes/PubkeyAuthentication yes/" "$SSH_CONFIG"
    sed -i "s/^PubkeyAuthentication .*/PubkeyAuthentication yes/" "$SSH_CONFIG"

    # Add allowed user
    echo "AllowUsers $USER" >>"$SSH_CONFIG"

    # Set authentication methods
    echo "AuthenticationMethods $AUTH_METHODS" >>"$SSH_CONFIG"

    # Setup key authentication for the user
    mkdir -p "$USER_HOME/.ssh"
    touch "$USER_HOME/.ssh/authorized_keys"
    chmod 700 "$USER_HOME/.ssh"
    chmod 600 "$USER_HOME/.ssh/authorized_keys"
    chown -R $USER:$USER "$USER_HOME/.ssh"

    if [[ "$AUTH_METHODS" == *"publickey"* ]]; then
        # Ask whether to create a keypair or provide one
        echo "Do you want to create a new SSH keypair? (yes/no, default: yes):"
        read -r CREATE_KEYPAIR
        CREATE_KEYPAIR=${CREATE_KEYPAIR:-yes}

        if [[ "$CREATE_KEYPAIR" == "yes" ]]; then
            ssh-keygen -t rsa -b 2048 -f "$USER_HOME/.ssh/id_rsa" -N ""
            cat "$USER_HOME/.ssh/id_rsa.pub" >>"$USER_HOME/.ssh/authorized_keys"
            chown -R $USER:$USER "$USER_HOME/.ssh"
            echo "SSH keypair created for user $USER."
            echo "Public Key:"
            cat "$USER_HOME/.ssh/id_rsa.pub"
            echo "Private Key:"
            cat "$USER_HOME/.ssh/id_rsa"
            echo "Please save the private key securely."
            echo "Press Enter to continue..."
            read -r
        else
            echo "Please paste your SSH public key (or leave empty to skip):"
            read -r SSH_KEY

            if [[ -n "$SSH_KEY" ]]; then
                echo "$SSH_KEY" >>"$USER_HOME/.ssh/authorized_keys"
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
        echo "3) Cancel configuration"
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
            # Restore original SSH config and exit
            cp "${SSH_CONFIG}.bak" "$SSH_CONFIG"
            echo "Configuration cancelled."
            return 1
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
        esac
    done
}

apply_ssh_config() {
    local SSH_PORT="$1"
    local USER="$2"
    local AUTH_METHODS="$3"               # e.g., publickey or publickey,password
    local PERMIT_ROOT_LOGIN="$4"          # yes|no
    local SSH_PUBKEY_INPUT="${5:-}"
    local GENERATE_KEYPAIR="${6:-yes}"

    if [[ -z "$SSH_PORT" || -z "$USER" ]]; then
        echo "apply_ssh_config: SSH port and user are required" >&2
        return 1
    fi

    local USER_HOME; USER_HOME=$([[ "$USER" == "root" ]] && echo "/root" || echo "/home/$USER")

    # Ensure user exists
    if ! id -u "$USER" >/dev/null 2>&1; then
        echo "User $USER does not exist; creating..."
        useradd -m -s /bin/bash "$USER"
        usermod -aG sudo "$USER"
    fi

    # Backup config once
    local SSH_CONFIG="/etc/ssh/sshd_config"
    [[ -f "${SSH_CONFIG}.bak" ]] || cp "$SSH_CONFIG" "${SSH_CONFIG}.bak"

    # Update key directives robustly
    if grep -qE '^#?Port ' "$SSH_CONFIG"; then
        sed -i "s/^#\?Port .*/Port $SSH_PORT/" "$SSH_CONFIG"
    else
        echo "Port $SSH_PORT" >> "$SSH_CONFIG"
    fi

    if grep -qE '^#?PermitRootLogin ' "$SSH_CONFIG"; then
        sed -i "s/^#\?PermitRootLogin .*/PermitRootLogin $PERMIT_ROOT_LOGIN/" "$SSH_CONFIG"
    else
        echo "PermitRootLogin $PERMIT_ROOT_LOGIN" >> "$SSH_CONFIG"
    fi

    if [[ "$AUTH_METHODS" == *"password"* ]]; then
        sed -i "s/^#\?PasswordAuthentication .*/PasswordAuthentication yes/" "$SSH_CONFIG"
    else
        sed -i "s/^#\?PasswordAuthentication .*/PasswordAuthentication no/" "$SSH_CONFIG"
    fi

    sed -i "s/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/" "$SSH_CONFIG" || echo "PubkeyAuthentication yes" >> "$SSH_CONFIG"

    # Add AllowUsers (ensure idempotent)
    grep -q "^AllowUsers .*\b$USER\b" "$SSH_CONFIG" || echo "AllowUsers $USER" >> "$SSH_CONFIG"

    # AuthenticationMethods
    if grep -q '^AuthenticationMethods ' "$SSH_CONFIG"; then
        sed -i "s/^AuthenticationMethods .*/AuthenticationMethods $AUTH_METHODS/" "$SSH_CONFIG"
    else
        echo "AuthenticationMethods $AUTH_METHODS" >> "$SSH_CONFIG"
    fi

    # Setup authorized_keys
    install -d -m 700 "$USER_HOME/.ssh"
    touch "$USER_HOME/.ssh/authorized_keys"
    chmod 600 "$USER_HOME/.ssh/authorized_keys"
    chown -R "$USER:$USER" "$USER_HOME/.ssh"

    if [[ "$AUTH_METHODS" == *"publickey"* ]]; then
        if [[ "$GENERATE_KEYPAIR" == "yes" ]]; then
            if [[ ! -f "$USER_HOME/.ssh/id_ed25519" ]]; then
                sudo -iu "$USER" ssh-keygen -t ed25519 -N "" -f "$USER_HOME/.ssh/id_ed25519" <<<"" >/dev/null 2>&1 || true
            fi
            cat "$USER_HOME/.ssh/id_ed25519.pub" >> "$USER_HOME/.ssh/authorized_keys"
        elif [[ -n "$SSH_PUBKEY_INPUT" ]]; then
            grep -qF "$SSH_PUBKEY_INPUT" "$USER_HOME/.ssh/authorized_keys" || echo "$SSH_PUBKEY_INPUT" >> "$USER_HOME/.ssh/authorized_keys"
        fi
    fi

    systemctl restart ssh
}

apply_firewall() {
    local SSH_PORT="$1"
    apt-get install -y iptables-persistent >/dev/null 2>&1 || true
    iptables -F
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    iptables -A INPUT -p tcp --dport 8000 -j ACCEPT  # Yacht
    iptables -A INPUT -p tcp --dport 9443 -j ACCEPT  # Portainer
    iptables-save > /etc/iptables/rules.v4
}
