#!/bin/bash
# SSH configuration module
# Provides: prompt_ssh_config(), apply_ssh_config()
# Reads/writes: SSH_PORT, AUTH_METHODS, PERMIT_ROOT_LOGIN, GENERATE_SSH_KEYPAIR, SSH_PUBKEY

prompt_ssh_config() {
    local port_input auth_choice rootlogin_input gen_input

    echo ""
    echo "=== SSH Configuration ==="

    while true; do
        read -r -p "  SSH port [${SSH_PORT}]: " port_input
        port_input="${port_input:-$SSH_PORT}"
        if [[ "$port_input" =~ ^[0-9]+$ ]] && (( port_input >= 1 && port_input <= 65535 )); then
            SSH_PORT=$port_input
            break
        fi
        echo "  Invalid port. Enter a number between 1 and 65535."
    done

    read -r -p "  Permit root login? (yes/no) [${PERMIT_ROOT_LOGIN}]: " rootlogin_input
    rootlogin_input="${rootlogin_input:-$PERMIT_ROOT_LOGIN}"
    PERMIT_ROOT_LOGIN="$([[ "$rootlogin_input" == "yes" ]] && echo "yes" || echo "no")"

    echo ""
    echo "  Authentication methods:"
    echo "    1) publickey                 (most secure — recommended)"
    echo "    2) password"
    echo "    3) publickey,password        (publickey preferred, password fallback)"
    echo "    4) keyboard-interactive"
    echo "    5) publickey,keyboard-interactive"
    read -r -p "  Choice (1-5) [1]: " auth_choice
    case "${auth_choice:-1}" in
        2) AUTH_METHODS="password" ;;
        3) AUTH_METHODS="publickey,password" ;;
        4) AUTH_METHODS="keyboard-interactive" ;;
        5) AUTH_METHODS="publickey,keyboard-interactive" ;;
        *) AUTH_METHODS="publickey" ;;
    esac

    if [[ "$AUTH_METHODS" == *"publickey"* ]]; then
        read -r -p "  Generate new ed25519 SSH keypair for ${ADMIN_USER:-<user>}? (yes/no) [${GENERATE_SSH_KEYPAIR}]: " gen_input
        GENERATE_SSH_KEYPAIR="${gen_input:-$GENERATE_SSH_KEYPAIR}"
        if [[ "$GENERATE_SSH_KEYPAIR" != "yes" ]]; then
            echo "  Paste SSH public key (or leave empty to skip):"
            IFS= read -r SSH_PUBKEY || true
        else
            SSH_PUBKEY=""
        fi
    fi
}

# Write a key directive to sshd_config robustly (handles commented/missing lines).
_sshd_set() {
    local key="$1" val="$2" config="$3"
    if grep -qE "^#?${key}\b" "$config" 2>/dev/null; then
        sed -i "s|^#\?${key}[[:space:]].*|${key} ${val}|" "$config"
    else
        echo "${key} ${val}" >> "$config"
    fi
}

apply_ssh_config() {
    local port="${1}"
    local user="${2}"
    local auth_methods="${3}"
    local permit_root="${4}"
    local pubkey_input="${5:-}"
    local gen_keypair="${6:-yes}"

    local sshd_config="/etc/ssh/sshd_config"
    local user_home

    if [[ -z "$port" || -z "$user" ]]; then
        echo "apply_ssh_config: SSH port and user are required" >&2
        return 1
    fi

    if ! id -u "$user" >/dev/null 2>&1; then
        echo "apply_ssh_config: user '$user' does not exist" >&2
        return 1
    fi

    user_home="$([[ "$user" == "root" ]] && echo "/root" || echo "/home/$user")"

    # Backup original config once
    [[ -f "${sshd_config}.bak" ]] || cp "$sshd_config" "${sshd_config}.bak"

    _sshd_set "Port"               "$port"        "$sshd_config"
    _sshd_set "PermitRootLogin"    "$permit_root" "$sshd_config"
    _sshd_set "PubkeyAuthentication" "yes"        "$sshd_config"
    _sshd_set "X11Forwarding"      "no"           "$sshd_config"
    _sshd_set "MaxAuthTries"       "3"            "$sshd_config"
    _sshd_set "ClientAliveInterval" "300"         "$sshd_config"
    _sshd_set "ClientAliveCountMax" "2"           "$sshd_config"
    _sshd_set "LoginGraceTime"     "30"           "$sshd_config"

    if [[ "$auth_methods" == *"password"* ]]; then
        _sshd_set "PasswordAuthentication" "yes" "$sshd_config"
    else
        _sshd_set "PasswordAuthentication" "no"  "$sshd_config"
    fi

    # AllowUsers — idempotent append
    if ! grep -qE "^AllowUsers\b.*\b${user}\b" "$sshd_config"; then
        # Replace existing AllowUsers line or append new one
        if grep -q "^AllowUsers " "$sshd_config"; then
            sed -i "s|^AllowUsers .*|& $user|" "$sshd_config"
        else
            echo "AllowUsers ${user}" >> "$sshd_config"
        fi
    fi

    # AuthenticationMethods — idempotent
    if grep -q "^AuthenticationMethods " "$sshd_config"; then
        sed -i "s|^AuthenticationMethods .*|AuthenticationMethods ${auth_methods}|" "$sshd_config"
    else
        echo "AuthenticationMethods ${auth_methods}" >> "$sshd_config"
    fi

    # Setup .ssh directory and authorized_keys
    install -d -m 700 -o "$user" -g "$user" "${user_home}/.ssh"
    [[ -f "${user_home}/.ssh/authorized_keys" ]] || touch "${user_home}/.ssh/authorized_keys"
    chmod 600 "${user_home}/.ssh/authorized_keys"
    chown "${user}:${user}" "${user_home}/.ssh/authorized_keys"

    # Key management
    if [[ "$auth_methods" == *"publickey"* ]]; then
        if [[ "$gen_keypair" == "yes" ]]; then
            if [[ ! -f "${user_home}/.ssh/id_ed25519" ]]; then
                sudo -u "$user" \
                    ssh-keygen -t ed25519 -N "" -f "${user_home}/.ssh/id_ed25519" </dev/null
                chown "${user}:${user}" \
                    "${user_home}/.ssh/id_ed25519" \
                    "${user_home}/.ssh/id_ed25519.pub"
            fi
            local pub_key
            pub_key="$(cat "${user_home}/.ssh/id_ed25519.pub")"
            grep -qF "$pub_key" "${user_home}/.ssh/authorized_keys" \
                || echo "$pub_key" >> "${user_home}/.ssh/authorized_keys"
        elif [[ -n "$pubkey_input" ]]; then
            grep -qF "$pubkey_input" "${user_home}/.ssh/authorized_keys" \
                || echo "$pubkey_input" >> "${user_home}/.ssh/authorized_keys"
        fi
    fi

    # Validate the config before restarting
    if ! sshd -t -f "$sshd_config"; then
        echo "[ERROR] sshd config validation failed — restoring backup" >&2
        cp "${sshd_config}.bak" "$sshd_config"
        return 1
    fi

    systemctl restart ssh
    echo "SSH configured on port ${port} for user ${user}."
}
