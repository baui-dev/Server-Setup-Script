#!/bin/bash
# Container engine selection module
# Provides: prompt_container_engine()
# Reads/writes: CONTAINER_ENGINE, PODMAN_SOURCE

prompt_container_engine() {
    local choice src_choice

    echo ""
    echo "=== Container Engine ==="
    printf "  1) Docker           (standard, daemon runs as root)\n"
    printf "  2) Docker Rootless  (daemon runs as %s)\n" "${ADMIN_USER:-<user>}"
    printf "  3) Podman           (daemonless, standard)\n"
    printf "  4) Podman Rootless  (daemonless, runs as %s)\n" "${ADMIN_USER:-<user>}"
    echo ""
    read -r -p "Select (1-4) [1]: " choice

    case "${choice:-1}" in
        2) CONTAINER_ENGINE="docker-rootless" ;;
        3) CONTAINER_ENGINE="podman" ;;
        4) CONTAINER_ENGINE="podman-rootless" ;;
        *) CONTAINER_ENGINE="docker" ;;
    esac

    # Rootless sanity check (advisory only at prompt time; validate_config enforces)
    if [[ "$CONTAINER_ENGINE" == *"rootless"* && ( -z "${ADMIN_USER:-}" || "${ADMIN_USER:-}" == "root" ) ]]; then
        echo "  [WARN] Rootless mode requires a non-root user — please configure one in the User section."
    fi

    if [[ "$CONTAINER_ENGINE" == podman* ]]; then
        echo ""
        echo "  Podman installation source:"
        echo "    1) GitHub release   (latest upstream binary — recommended for fresh Debian)"
        echo "    2) Debian repository (distro-provided, may be older)"
        echo "    3) Alvistack        (up-to-date packages for Debian)"
        read -r -p "  Select (1-3) [1]: " src_choice
        case "${src_choice:-1}" in
            2) PODMAN_SOURCE="debian" ;;
            3) PODMAN_SOURCE="alvistack" ;;
            *) PODMAN_SOURCE="github" ;;
        esac
    fi

    echo "  Container engine: ${CONTAINER_ENGINE}"
}
