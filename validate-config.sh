#!/bin/bash
# Configuration validation module
# Provides: get_manager_ports(), validate_config()
# All functions are pure — they only read global variables, never modify them.

# Returns space-separated list of TCP ports used by a given container manager.
get_manager_ports() {
    case "${1:-none}" in
        portainer) echo "9000 9443" ;;
        cockpit)   echo "9090" ;;
        yacht)     echo "8000" ;;
        komodo)    echo "9120" ;;
        dweebui)   echo "7125" ;;
        dockge)    echo "5001" ;;
        none|"")   echo "" ;;
        *)         echo "" ;;
    esac
}

# Validates the current global config variables.
# Prints warnings/errors to stdout.
# Returns the number of hard errors (non-zero = do not apply).
validate_config() {
    local errors=0
    local warnings=0
    local -a issues=()

    local manager_ports
    manager_ports="$(get_manager_ports "${CONTAINER_MANAGER:-portainer}")"

    # ── SSH ──────────────────────────────────────────────────────────────────
    if [[ "${SSH_PORT:-22}" -eq 22 ]]; then
        issues+=("[WARN] SSH is on default port 22 — consider a non-standard port (e.g. 2222)")
        (( warnings++ )) || true
    fi

    if [[ "${PERMIT_ROOT_LOGIN:-no}" == "yes" ]]; then
        issues+=("[WARN] PermitRootLogin is enabled — this is a security risk")
        (( warnings++ )) || true
    fi

    if [[ "${AUTH_METHODS:-publickey}" == "password" ]]; then
        issues+=("[WARN] Password-only authentication — publickey is strongly recommended")
        (( warnings++ )) || true
    fi

    if [[ "${AUTH_METHODS:-publickey}" == *"publickey"* \
       && "${GENERATE_SSH_KEYPAIR:-yes}" != "yes" \
       && -z "${SSH_PUBKEY:-}" ]]; then
        issues+=("[ERROR] Publickey auth selected but no key will be installed — you WILL be locked out!")
        (( errors++ )) || true
    fi

    # ── User ─────────────────────────────────────────────────────────────────
    if [[ -z "${ADMIN_USER:-}" ]]; then
        issues+=("[WARN] No admin user configured — SSH AllowUsers will not be set")
        (( warnings++ )) || true
    fi

    # ── Containers ───────────────────────────────────────────────────────────
    if [[ "${CONTAINER_ENGINE:-docker}" == *"rootless"* ]]; then
        if [[ -z "${ADMIN_USER:-}" || "${ADMIN_USER:-}" == "root" ]]; then
            issues+=("[ERROR] Rootless containers cannot run as root — set a non-root ADMIN_USER")
            (( errors++ )) || true
        fi
    fi

    if [[ "${CONTAINER_MANAGER:-portainer}" == "komodo" \
       && "${CONTAINER_ENGINE:-docker}" != "docker" ]]; then
        issues+=("[WARN] Komodo requires Docker engine (current: ${CONTAINER_ENGINE}) — will fall back to Portainer")
        (( warnings++ )) || true
    fi

    # ── Port conflicts ────────────────────────────────────────────────────────
    for mp in $manager_ports; do
        [[ -z "$mp" ]] && continue
        if (( mp == SSH_PORT )); then
            issues+=("[ERROR] ${CONTAINER_MANAGER} port ${mp} conflicts with SSH port ${SSH_PORT}")
            (( errors++ )) || true
        fi
    done

    # Check for duplicates inside extra ports
    local -a seen_ports=()
    for p in ${EXTRA_OPEN_PORTS:-}; do
        [[ -z "$p" ]] && continue
        for s in "${seen_ports[@]:-}"; do
            if [[ "$p" == "$s" ]]; then
                issues+=("[WARN] Duplicate port $p in EXTRA_OPEN_PORTS")
                (( warnings++ )) || true
                break
            fi
        done
        seen_ports+=("$p")
    done

    # ── Security ─────────────────────────────────────────────────────────────
    if [[ "${SECURITY_HARDENING:-yes}" == "yes" \
       && "${SECURITY_FAIL2BAN:-yes}" != "yes" \
       && "${AUTH_METHODS:-publickey}" == *"password"* ]]; then
        issues+=("[WARN] Password auth enabled without fail2ban — brute-force risk")
        (( warnings++ )) || true
    fi

    # ── Print results ─────────────────────────────────────────────────────────
    if (( ${#issues[@]} > 0 )); then
        echo "┌── Validation ──────────────────────────────────────────────┐"
        for issue in "${issues[@]}"; do
            printf "│  %s\n" "$issue"
        done
        echo "├────────────────────────────────────────────────────────────┤"
        if (( errors > 0 )); then
            printf "│  %d error(s) — resolve before applying configuration\n" "$errors"
        fi
        if (( warnings > 0 )); then
            printf "│  %d warning(s) — review before proceeding\n" "$warnings"
        fi
        echo "└────────────────────────────────────────────────────────────┘"
    else
        echo "  [OK] Configuration looks good — no issues found."
    fi

    return $errors
}

# Prints actionable suggestions for common issues.
suggest_fixes() {
    local manager_ports
    manager_ports="$(get_manager_ports "${CONTAINER_MANAGER:-portainer}")"

    echo ""
    echo "=== Suggested Fixes ============================="

    if [[ "${SSH_PORT:-22}" -eq 22 ]]; then
        local suggested_port=$(( (RANDOM % 50000) + 10000 ))
        echo "  - Change SSH_PORT to ${suggested_port} (or any port 1024-65535)"
    fi

    if [[ "${PERMIT_ROOT_LOGIN:-no}" == "yes" ]]; then
        echo "  - Set PERMIT_ROOT_LOGIN=\"no\" and use sudo for admin tasks"
    fi

    if [[ "$CONTAINER_MANAGER" == "komodo" && "${CONTAINER_ENGINE:-docker}" != "docker" ]]; then
        echo "  - Change CONTAINER_MANAGER to \"portainer\" or CONTAINER_ENGINE to \"docker\""
    fi

    if [[ -n "$manager_ports" ]]; then
        echo "  - Manager port(s) ${manager_ports} will be opened automatically by the firewall step"
    fi

    echo "================================================="
}
