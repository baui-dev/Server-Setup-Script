#!/bin/bash
# User configuration module
# Provides: prompt_user_config(), apply_user_config()
# Reads/writes: ADMIN_USER, CREATE_ADMIN_USER

prompt_user_config() {
    local -a arr=()
    local i choice

    echo ""
    echo "=== User Configuration ==="

    mapfile -t arr < <(awk -F: '($3>=1000)&&($1!="nobody"){print $1}' /etc/passwd 2>/dev/null || true)

    if (( ${#arr[@]} > 0 )); then
        echo "Existing non-root users:"
        i=1
        for u in "${arr[@]}"; do
            printf "  %d) %s\n" "$i" "$u"
            (( i++ )) || true
        done
        printf "  %d) Create new user\n" "$i"
        echo ""
        read -r -p "Select (1-${i}): " choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice < i )); then
            ADMIN_USER="${arr[$((choice-1))]}"
            CREATE_ADMIN_USER=0
            echo "  Using existing user: ${ADMIN_USER}"
        else
            _prompt_new_username
        fi
    else
        echo "  No non-root users found on this system."
        _prompt_new_username
    fi
}

_prompt_new_username() {
    while true; do
        read -r -p "  New username: " ADMIN_USER
        if [[ -n "$ADMIN_USER" && "$ADMIN_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
            break
        fi
        echo "  Invalid username. Use lowercase letters, numbers, hyphens, underscores."
    done
    CREATE_ADMIN_USER=1
}

apply_user_config() {
    if [[ -z "${ADMIN_USER:-}" ]]; then
        echo "No admin user configured; skipping user creation." >&2
        return
    fi

    if id -u "$ADMIN_USER" >/dev/null 2>&1; then
        echo "User ${ADMIN_USER} already exists — skipping creation."
        CREATE_ADMIN_USER=0
        return
    fi

    if (( CREATE_ADMIN_USER == 1 )); then
        echo "Creating user ${ADMIN_USER}..."
        useradd -m -s /bin/bash "$ADMIN_USER"
        usermod -aG sudo "$ADMIN_USER"
        echo ""
        echo "Set password for ${ADMIN_USER}:"
        passwd "$ADMIN_USER"
        # Sudoers entry requiring password (not NOPASSWD, for security)
        echo "${ADMIN_USER} ALL=(ALL:ALL) ALL" > "/etc/sudoers.d/90-${ADMIN_USER}"
        chmod 440 "/etc/sudoers.d/90-${ADMIN_USER}"
        echo "User ${ADMIN_USER} created with sudo access."
    fi
}
