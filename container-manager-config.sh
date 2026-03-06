#!/bin/bash
# Container manager prompts and install functions
# Provides: prompt_container_manager(), install_container_manager(), _run_as_user()
# Individual installers: install_portainer, install_cockpit, install_yacht,
#                        install_dockge, install_komodo, install_dweebui
# Requires: get_manager_ports() from validate-config.sh

prompt_container_manager() {
    local choice

    echo ""
    echo "=== Container Manager ==="
    echo "  1) Portainer  — web UI for Docker/Podman          (port 9443)"
    echo "  2) Cockpit    — system + container management      (port 9090)"
    echo "  3) Komodo     — GitOps-style manager (Docker only) (port 9120)"
    echo "  4) Yacht      — simple container UI                (port 8000)"
    echo "  5) Dweebui    — minimal container UI               (port 7125)"
    echo "  6) Dockge     — compose file manager               (port 5001)"
    echo "  7) None"
    echo ""
    read -r -p "Select (1-7) [1]: " choice

    case "${choice:-1}" in
        2) CONTAINER_MANAGER="cockpit"   ;;
        3) CONTAINER_MANAGER="komodo"    ;;
        4) CONTAINER_MANAGER="yacht"     ;;
        5) CONTAINER_MANAGER="dweebui"   ;;
        6) CONTAINER_MANAGER="dockge"    ;;
        7) CONTAINER_MANAGER="none"      ;;
        *) CONTAINER_MANAGER="portainer" ;;
    esac

    # Komodo compatibility guard — must happen at prompt time so validation
    # catches it and the user can be informed immediately.
    if [[ "$CONTAINER_MANAGER" == "komodo" && "${CONTAINER_ENGINE:-docker}" != "docker" ]]; then
        echo "  [WARN] Komodo requires Docker. Switching to Portainer for ${CONTAINER_ENGINE}."
        CONTAINER_MANAGER="portainer"
    fi

    echo "  Container manager: ${CONTAINER_MANAGER}"
    local ports
    ports="$(get_manager_ports "$CONTAINER_MANAGER")"
    [[ -n "$ports" ]] && echo "  Port(s) to be opened: ${ports}"
}

# Helper — run a command as a non-root user, preserving their login environment.
_run_as_user() {
    local target_user="$1"; shift
    sudo -iu "$target_user" bash -lc "$*"
}

# ── Portainer ─────────────────────────────────────────────────────────────────
install_portainer() {
    local engine="${1:-docker}"
    local target_user="${2:-${ADMIN_USER:-root}}"
    echo "Installing Portainer..."
    case "$engine" in
        docker)
            docker volume create portainer_data 2>/dev/null || true
            docker run -d \
                --name=portainer --restart=always \
                -p 9000:9000 -p 9443:9443 \
                -v /var/run/docker.sock:/var/run/docker.sock \
                -v portainer_data:/data \
                portainer/portainer-ce:latest
            ;;
        docker-rootless)
            _run_as_user "$target_user" "docker volume create portainer_data 2>/dev/null || true"
            _run_as_user "$target_user" \
                "docker run -d --name=portainer --restart=always \
                 -p 9000:9000 -p 9443:9443 \
                 -v \$XDG_RUNTIME_DIR/docker.sock:/var/run/docker.sock \
                 -v portainer_data:/data \
                 portainer/portainer-ce:latest"
            ;;
        podman|podman-rootless)
            _run_as_user "$target_user" "podman volume create portainer_data 2>/dev/null || true"
            _run_as_user "$target_user" \
                "podman run -d --name=portainer --restart=always \
                 -p 9000:9000 -p 9443:9443 \
                 -v \$XDG_RUNTIME_DIR/podman/podman.sock:/var/run/docker.sock:ro \
                 -v portainer_data:/data \
                 portainer/portainer-ce:latest"
            ;;
        *) echo "install_portainer: unknown engine '${engine}'" ;;
    esac
    echo "  Portainer → https://<server>:9443"
}

# ── Cockpit ───────────────────────────────────────────────────────────────────
install_cockpit() {
    local engine="${1:-docker}"
    echo "Installing Cockpit..."
    local pkgs="cockpit"
    # Install the engine-appropriate plugin — not always cockpit-podman
    case "$engine" in
        podman|podman-rootless) pkgs="$pkgs cockpit-podman" ;;
        # cockpit-machines provides VM integration; no dedicated Docker plugin
    esac
    DEBIAN_FRONTEND=noninteractive apt-get install -y $pkgs
    systemctl enable --now cockpit.socket
    echo "  Cockpit → https://<server>:9090"
}

# ── Yacht ─────────────────────────────────────────────────────────────────────
install_yacht() {
    local engine="${1:-docker}"
    local target_user="${2:-${ADMIN_USER:-root}}"
    echo "Installing Yacht..."
    case "$engine" in
        docker)
            docker volume create yacht_data 2>/dev/null || true
            docker run -d \
                --name=yacht --restart=always \
                -p 8000:8000 \
                -v /var/run/docker.sock:/var/run/docker.sock \
                -v yacht_data:/config \
                selfhostedpro/yacht:latest
            ;;
        docker-rootless)
            _run_as_user "$target_user" "docker volume create yacht_data 2>/dev/null || true"
            _run_as_user "$target_user" \
                "docker run -d --name=yacht --restart=always \
                 -p 8000:8000 \
                 -v \$XDG_RUNTIME_DIR/docker.sock:/var/run/docker.sock \
                 -v yacht_data:/config \
                 selfhostedpro/yacht:latest"
            ;;
        podman|podman-rootless)
            _run_as_user "$target_user" "podman volume create yacht_data 2>/dev/null || true"
            _run_as_user "$target_user" \
                "podman run -d --name=yacht --restart=always \
                 -p 8000:8000 \
                 -v \$XDG_RUNTIME_DIR/podman/podman.sock:/var/run/docker.sock:ro \
                 -v yacht_data:/config \
                 selfhostedpro/yacht:latest"
            ;;
        *) echo "install_yacht: unknown engine '${engine}'" ;;
    esac
    echo "  Yacht → http://<server>:8000"
    echo "  Default login: admin@yacht.local / pass: password  (CHANGE THIS)"
}

# ── Dockge ────────────────────────────────────────────────────────────────────
install_dockge() {
    local engine="${1:-docker}"
    local target_user="${2:-${ADMIN_USER:-root}}"
    echo "Installing Dockge..."
    mkdir -p /opt/dockge/data /opt/stacks
    curl -fsSL \
        "https://raw.githubusercontent.com/louislam/dockge/master/compose.yaml" \
        -o /opt/dockge/compose.yaml
    case "$engine" in
        docker|docker-rootless)
            docker compose -f /opt/dockge/compose.yaml up -d
            ;;
        podman|podman-rootless)
            _run_as_user "$target_user" "podman-compose -f /opt/dockge/compose.yaml up -d"
            ;;
        *) echo "install_dockge: unknown engine '${engine}'" ;;
    esac
    echo "  Dockge → http://<server>:5001"
}

# ── Komodo ────────────────────────────────────────────────────────────────────
install_komodo() {
    echo "  [INFO] Komodo installation not yet implemented — skipping."
}

# ── DweebUI ───────────────────────────────────────────────────────────────────
install_dweebui() {
    echo "  [INFO] DweebUI installation not yet implemented — skipping."
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
install_container_manager() {
    local manager="${1:-none}"
    local engine="${2:-docker}"
    local user="${3:-root}"
    case "$manager" in
        portainer) install_portainer "$engine" "$user" ;;
        cockpit)   install_cockpit   "$engine"         ;;
        yacht)     install_yacht     "$engine" "$user" ;;
        komodo)    install_komodo ;;
        dweebui)   install_dweebui ;;
        dockge)    install_dockge    "$engine" "$user" ;;
        none|"")   echo "No container manager selected — skipping." ;;
        *)         echo "Unknown container manager: ${manager} — skipping." ;;
    esac
}
