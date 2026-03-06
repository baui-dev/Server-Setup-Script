#!/bin/bash
# Network / Firewall configuration module
# Provides: prompt_network_config(), apply_firewall()
# Reads/writes: EXTRA_OPEN_PORTS
# Requires: get_manager_ports() from validate-config.sh

prompt_network_config() {
    local extra_input
    local manager_ports
    manager_ports="$(get_manager_ports "${CONTAINER_MANAGER:-none}")"

    echo ""
    echo "=== Firewall Configuration ==="
    echo "  The following ports are opened automatically:"
    printf "    • SSH:                   %s/tcp\n" "${SSH_PORT}"
    printf "    • HTTP/HTTPS:            80/tcp, 443/tcp\n"
    if [[ -n "$manager_ports" ]]; then
        printf "    • %s:  %s/tcp\n" "${CONTAINER_MANAGER}" "${manager_ports// /, }"
    fi
    echo ""
    if [[ -n "${EXTRA_OPEN_PORTS:-}" ]]; then
        echo "  Current extra open ports: ${EXTRA_OPEN_PORTS}"
    fi
    read -r -p "  Additional ports to open (space-separated, or Enter to keep current): " extra_input
    if [[ -n "$extra_input" ]]; then
        EXTRA_OPEN_PORTS="$extra_input"
    fi
}

apply_firewall() {
    local ssh_port="${1:-22}"
    local manager="${2:-none}"
    local extra_ports="${3:-}"

    echo "Configuring UFW firewall..."

    apt-get install -y ufw >/dev/null 2>&1 || true

    # Disable before reconfiguring to avoid locking ourselves out mid-setup
    ufw --force disable

    # Reset rules to clear any previous state
    ufw --force reset

    ufw default deny incoming
    ufw default allow outgoing
    ufw logging on

    # SSH — always first so we never lock ourselves out
    ufw allow "${ssh_port}/tcp" comment "SSH"

    # HTTP / HTTPS — common for reverse proxies and healthchecks
    ufw allow 80/tcp comment "HTTP"
    ufw allow 443/tcp comment "HTTPS"

    # Container manager ports (derived from selection, not hardcoded)
    local manager_ports
    manager_ports="$(get_manager_ports "$manager")"
    for p in $manager_ports; do
        [[ -z "$p" ]] && continue
        ufw allow "${p}/tcp" comment "Container manager: ${manager}"
    done

    # User-supplied extra ports
    for p in $extra_ports; do
        [[ -z "$p" ]] && continue
        if [[ "$p" =~ ^[0-9]+(/tcp|/udp)?$ ]]; then
            ufw allow "${p}" comment "Custom"
        else
            echo "  [WARN] Skipping invalid port spec: ${p}"
        fi
    done

    ufw --force enable
    ufw status verbose
    echo "Firewall configured."
}
