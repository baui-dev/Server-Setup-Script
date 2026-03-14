#!/usr/bin/env bash
# =============================================================================
# SERVER SETUP SCRIPT
# =============================================================================
# Interactive service selector that generates:
#   - .env configuration file
#   - Per-category Docker Compose stack files
#   - (Optionally) Reverse proxy configuration
#   - (Optionally) Dependency graph
#
# Usage: bash scripts/setup.sh [--non-interactive --services jellyfin,sonarr]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REGISTRY="${REPO_ROOT}/registry/services.json"
TEMPLATE_ENV="${REPO_ROOT}/templates/env-template.env"
OUTPUT_ENV="${REPO_ROOT}/.env"
STACKS_DIR="${REPO_ROOT}/stacks"

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

print_header()  { echo -e "\n${BOLD}${BLUE}═══ $1 ═══${RESET}\n"; }
print_info()    { echo -e "${CYAN}ℹ ${RESET}$1"; }
print_success() { echo -e "${GREEN}✓ ${RESET}$1"; }
print_error()   { echo -e "${RED}✗ ${RESET}$1" >&2; }
print_warn()    { echo -e "${YELLOW}⚠ ${RESET}$1"; }
print_dim()     { echo -e "\033[2m$1${RESET}"; }

# ─── Dependency Check ────────────────────────────────────────────────────────
check_dependencies() {
    local missing=()
    command -v jq      &>/dev/null || missing+=("jq")

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing required tools: ${missing[*]}"
        echo "Install with:"
        echo "  Debian/Ubuntu: sudo apt install ${missing[*]}"
        echo "  macOS:         brew install ${missing[*]}"
        exit 1
    fi

    if [[ ! -f "${REGISTRY}" ]]; then
        print_error "Registry not found: ${REGISTRY}"
        exit 1
    fi

    if [[ ! -f "${TEMPLATE_ENV}" ]]; then
        print_warn "Env template not found: ${TEMPLATE_ENV}"
        print_warn "A minimal .env will be generated without a base template."
    fi

    mkdir -p "${STACKS_DIR}"
}

# ─── Load Registry ───────────────────────────────────────────────────────────
# Parallel arrays (bash 3 compat backup — we target bash 4 assoc arrays)
declare -a SVC_NAMES=()        # [idx] = service_name
declare -a SVC_DISPLAY=()      # [idx] = display_name
declare -a SVC_CATEGORY=()     # [idx] = category
declare -a SVC_SUBCAT=()       # [idx] = subcategory
declare -a SVC_DESC=()         # [idx] = description
declare -a SVC_PORTS=()        # [idx] = "PORT_A PORT_B ..." (space-sep)
declare -a SVC_REQUIRES=()     # [idx] = "dep1 dep2 ..." (space-sep)
declare -A NAME_TO_IDX=()      # name -> index
declare -A SELECTED=()         # name -> 1 if selected

load_registry() {
    local count
    count=$(jq '.services | length' "${REGISTRY}")
    local i
    for (( i=0; i<count; i++ )); do
        local svc
        svc=$(jq -c ".services[${i}]" "${REGISTRY}")

        local name display category subcat desc ports requires
        name=$(jq -r '.name'         <<< "${svc}")
        display=$(jq -r '.display_name // .name' <<< "${svc}")
        category=$(jq -r '.category' <<< "${svc}")
        subcat=$(jq -r '.subcategory // ""' <<< "${svc}")
        desc=$(jq -r '.description // ""'   <<< "${svc}")
        ports=$(jq -r '(.ports // []) | join(" ")'    <<< "${svc}")
        requires=$(jq -r '(.requires // []) | join(" ")' <<< "${svc}")

        SVC_NAMES+=("${name}")
        SVC_DISPLAY+=("${display}")
        SVC_CATEGORY+=("${category}")
        SVC_SUBCAT+=("${subcat}")
        SVC_DESC+=("${desc}")
        SVC_PORTS+=("${ports}")
        SVC_REQUIRES+=("${requires}")
        NAME_TO_IDX["${name}"]="${i}"
    done
}

# ─── Display Menu ────────────────────────────────────────────────────────────
display_menu() {
    clear
    echo -e "${BOLD}${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              SERVER SETUP SCRIPT  v1.0                      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    local selected_count=0
    for name in "${!SELECTED[@]}"; do
        [[ "${SELECTED[$name]}" -eq 1 ]] && (( selected_count++ )) || true
    done

    echo -e "  ${CYAN}Selected: ${BOLD}${selected_count}${RESET}${CYAN} service(s)${RESET}\n"

    local current_cat="" current_sub=""
    local idx=0
    local total=${#SVC_NAMES[@]}

    for (( idx=0; idx<total; idx++ )); do
        local name="${SVC_NAMES[$idx]}"
        local cat="${SVC_CATEGORY[$idx]}"
        local sub="${SVC_SUBCAT[$idx]}"
        local display="${SVC_DISPLAY[$idx]}"
        local desc="${SVC_DESC[$idx]}"

        if [[ "${cat}" != "${current_cat}" ]]; then
            current_cat="${cat}"
            current_sub=""
            echo -e "  ${BOLD}${YELLOW}[ ${cat^^} ]${RESET}"
        fi

        if [[ -n "${sub}" && "${sub}" != "${current_sub}" ]]; then
            current_sub="${sub}"
            echo -e "    ${BOLD}${CYAN}─ ${sub}${RESET}"
        fi

        local check=" "
        if [[ -n "${SELECTED[$name]+x}" && "${SELECTED[$name]}" -eq 1 ]]; then
            check="${GREEN}✓${RESET}"
        fi

        # Pad number to 2 chars, name to 20 chars
        local num_str
        printf -v num_str "%2d" $(( idx + 1 ))
        printf "    ${BOLD}%s.${RESET} [%b] %-20s %b\n" \
            "${num_str}" "${check}" "${display}" "\033[2m${desc}${RESET}"
    done

    echo ""
    echo -e "${BOLD}─── Commands ───────────────────────────────────────────────────${RESET}"
    echo "  Enter number(s) to toggle  │  e.g.:  1 3 5   or   2-8"
    echo "  all                        │  Select all services"
    echo "  clear                      │  Deselect all services"
    echo "  cat:<name>                 │  Toggle all in category (e.g. cat:media)"
    echo "  recommended                │  Select recommended media server stack"
    echo "  done                       │  Proceed with current selection"
    echo "  quit / exit                │  Exit without generating anything"
    echo -e "${BOLD}────────────────────────────────────────────────────────────────${RESET}"
}

# ─── Toggle helpers ──────────────────────────────────────────────────────────
toggle_service() {
    local name="$1"
    if [[ -z "${NAME_TO_IDX[$name]+x}" ]]; then
        print_warn "Unknown service: ${name}"
        return
    fi
    if [[ -n "${SELECTED[$name]+x}" && "${SELECTED[$name]}" -eq 1 ]]; then
        SELECTED["${name}"]=0
    else
        SELECTED["${name}"]=1
    fi
}

select_all() {
    local name
    for name in "${SVC_NAMES[@]}"; do
        SELECTED["${name}"]=1
    done
}

clear_all() {
    local name
    for name in "${SVC_NAMES[@]}"; do
        SELECTED["${name}"]=0
    done
}

select_category() {
    local target_cat="${1,,}"
    local found=0
    local i
    for (( i=0; i<${#SVC_NAMES[@]}; i++ )); do
        local cat="${SVC_CATEGORY[$i],,}"
        local sub="${SVC_SUBCAT[$i],,}"
        if [[ "${cat}" == "${target_cat}" || "${sub}" == "${target_cat}" ]]; then
            SELECTED["${SVC_NAMES[$i]}"]=1
            found=1
        fi
    done
    if [[ "${found}" -eq 0 ]]; then
        print_warn "No services found for category: ${target_cat}"
    fi
}

select_recommended() {
    # A reasonable default: core media server + management
    local recommended=(
        jellyfin sonarr radarr bazarr prowlarr jellyseerr
        qbittorrent recyclarr maintainerr
        homepage portainer watchtower dozzle
        uptime-kuma
    )
    local svc
    for svc in "${recommended[@]}"; do
        if [[ -n "${NAME_TO_IDX[$svc]+x}" ]]; then
            SELECTED["${svc}"]=1
        fi
    done
    print_info "Recommended media stack selected."
}

# ─── Dependency Resolution ───────────────────────────────────────────────────
resolve_dependencies() {
    local changed=1
    while [[ "${changed}" -eq 1 ]]; do
        changed=0
        local i
        for (( i=0; i<${#SVC_NAMES[@]}; i++ )); do
            local name="${SVC_NAMES[$i]}"
            if [[ -z "${SELECTED[$name]+x}" || "${SELECTED[$name]}" -ne 1 ]]; then
                continue
            fi
            local req
            for req in ${SVC_REQUIRES[$i]}; do
                if [[ -n "${NAME_TO_IDX[$req]+x}" ]]; then
                    if [[ -z "${SELECTED[$req]+x}" || "${SELECTED[$req]}" -ne 1 ]]; then
                        SELECTED["${req}"]=1
                        changed=1
                        print_info "Auto-added dependency: ${req} (required by ${name})"
                    fi
                else
                    print_warn "Dependency '${req}' (required by ${name}) not found in registry."
                fi
            done
        done
    done
}

# ─── Port Conflict Detection ─────────────────────────────────────────────────
detect_port_conflicts() {
    # Read actual port values from env-template or .env to find numeric conflicts
    local env_file="${OUTPUT_ENV}"
    [[ -f "${env_file}" ]] || env_file="${TEMPLATE_ENV}"
    [[ -f "${env_file}" ]] || return 0

    declare -A port_to_vars=()
    local conflicts=0

    # Build a map of selected services' port variable names
    declare -A selected_port_vars=()
    local i
    for (( i=0; i<${#SVC_NAMES[@]}; i++ )); do
        local name="${SVC_NAMES[$i]}"
        if [[ -n "${SELECTED[$name]+x}" && "${SELECTED[$name]}" -eq 1 ]]; then
            local pvar
            for pvar in ${SVC_PORTS[$i]}; do
                selected_port_vars["${pvar}"]=1
            done
        fi
    done

    # Now read port values from env file for selected vars
    declare -A port_val_to_vars=()
    local line varname value
    while IFS= read -r line; do
        [[ "${line}" =~ ^[[:space:]]*# ]] && continue
        [[ "${line}" =~ ^[[:space:]]*$ ]] && continue
        if [[ "${line}" =~ ^([A-Za-z_][A-Za-z_0-9]*)=([0-9]+)$ ]]; then
            varname="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            if [[ -n "${selected_port_vars[$varname]+x}" ]]; then
                if [[ -n "${port_val_to_vars[$value]+x}" ]]; then
                    print_warn "Port conflict: ${value} used by both '${port_val_to_vars[$value]}' and '${varname}'"
                    conflicts=$(( conflicts + 1 ))
                else
                    port_val_to_vars["${value}"]="${varname}"
                fi
            fi
        fi
    done < "${env_file}"

    if [[ "${conflicts}" -gt 0 ]]; then
        print_warn "${conflicts} port conflict(s) detected. Edit ${OUTPUT_ENV} to resolve before starting services."
    fi
}

# ─── Deterministic Auto-Port Assignment ──────────────────────────────────────
declare -A AUTO_PORT_ASSIGNMENTS=()

get_base_port() {
    local base=30000
    local candidate

    candidate=$(awk -F= '/^BASE_PORT=[0-9]+$/ { print $2; exit }' "${TEMPLATE_ENV}" 2>/dev/null || true)
    if [[ -n "${candidate}" && "${candidate}" =~ ^[0-9]+$ ]]; then
        base="${candidate}"
    fi

    echo "${base}"
}

assign_auto_ports() {
    AUTO_PORT_ASSIGNMENTS=()

    local base_port
    base_port="$(get_base_port)"

    # Reserve already-defined numeric PORT_* values from template to avoid accidental overlap.
    declare -A used_ports=()
    if [[ -f "${TEMPLATE_ENV}" ]]; then
        local line varname value
        while IFS= read -r line; do
            [[ "${line}" =~ ^[[:space:]]*# ]] && continue
            [[ "${line}" =~ ^([A-Za-z_][A-Za-z_0-9]*)=([0-9]+)$ ]] || continue
            varname="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            if [[ "${varname}" =~ ^PORT_[A-Z0-9_]+$ ]]; then
                used_ports["${value}"]=1
            fi
        done < "${TEMPLATE_ENV}"
    fi

    local i
    local next_port="${base_port}"
    for (( i=0; i<${#SVC_NAMES[@]}; i++ )); do
        local svc_name="${SVC_NAMES[$i]}"
        [[ -n "${SELECTED[$svc_name]+x}" && "${SELECTED[$svc_name]}" -eq 1 ]] || continue

        local pvar
        for pvar in ${SVC_PORTS[$i]}; do
            [[ -n "${pvar}" ]] || continue
            [[ "${pvar}" =~ ^PORT_[A-Z0-9_]+$ ]] || continue

            local auto_var="${pvar/PORT_/AUTO_PORT_}"
            if [[ -n "${AUTO_PORT_ASSIGNMENTS[$auto_var]+x}" ]]; then
                continue
            fi

            while [[ -n "${used_ports[$next_port]+x}" ]]; do
                next_port=$(( next_port + 1 ))
            done
            AUTO_PORT_ASSIGNMENTS["${auto_var}"]="${next_port}"
            used_ports["${next_port}"]=1
            next_port=$(( next_port + 1 ))
        done
    done
}

# ─── Generate .env ───────────────────────────────────────────────────────────
generate_env() {
    # Back up existing .env
    if [[ -f "${OUTPUT_ENV}" ]]; then
        local backup="${OUTPUT_ENV}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "${OUTPUT_ENV}" "${backup}"
        print_info "Existing .env backed up to: ${backup}"
    fi

    if [[ -f "${TEMPLATE_ENV}" ]]; then
        cp "${TEMPLATE_ENV}" "${OUTPUT_ENV}"
    else
        # Minimal fallback header
        cat > "${OUTPUT_ENV}" << 'EOF'
# Generated by scripts/setup.sh
TZ=UTC
PUID=1000
PGID=1000
DOCKER_DATA=/srv/dockerdata
DOCKER_LOGS=/srv/dockerlogs
DOCKER_BACKUPS=/srv/dockerbackups
BASE_DOMAIN=example.com
DEFAULT_NETWORK=proxy
BASE_PORT=30000
EOF
    fi

    assign_auto_ports

    local selected_list
    selected_list="$(get_selected_list)"

    {
        echo ""
        echo "# ── Auto-generated Selection (Do not edit YAML; configure here) ───────────────"
        echo "# Source of truth: registry/services.json + selected service list"
        echo "SELECTED_SERVICES=${selected_list}"
        echo ""
        echo "# Auto-assigned host ports"
        echo "# To override a port, set PORT_<SERVICE>=<PORT> below or elsewhere in this file."

        local i
        for (( i=0; i<${#SVC_NAMES[@]}; i++ )); do
            local svc_name="${SVC_NAMES[$i]}"
            [[ -n "${SELECTED[$svc_name]+x}" && "${SELECTED[$svc_name]}" -eq 1 ]] || continue

            local pvar
            for pvar in ${SVC_PORTS[$i]}; do
                [[ -n "${pvar}" ]] || continue
                [[ "${pvar}" =~ ^PORT_[A-Z0-9_]+$ ]] || continue

                local auto_var="${pvar/PORT_/AUTO_PORT_}"
                local auto_value="${AUTO_PORT_ASSIGNMENTS[$auto_var]:-}"
                [[ -n "${auto_value}" ]] || continue

                echo "${auto_var}=${auto_value}"
                echo "# ${pvar}="
            done
        done
    } >> "${OUTPUT_ENV}"

    print_success ".env generated: ${OUTPUT_ENV}"
}

# ─── Generate Stacks ─────────────────────────────────────────────────────────
generate_stacks() {
    local selected_list
    selected_list=$(get_selected_list)

    if [[ -z "${selected_list}" ]]; then
        print_warn "No services selected — skipping stack generation."
        return
    fi

    print_info "Running stack generator..."
    if bash "${SCRIPT_DIR}/generate-stacks.sh" --services "${selected_list}"; then
        print_success "Stacks generated in: ${STACKS_DIR}/"
    else
        print_error "Stack generation failed. Check output above."
    fi
}

# ─── Get comma-separated list of selected service names ──────────────────────
get_selected_list() {
    local list=""
    local name
    for name in "${SVC_NAMES[@]}"; do
        if [[ -n "${SELECTED[$name]+x}" && "${SELECTED[$name]}" -eq 1 ]]; then
            list="${list:+${list},}${name}"
        fi
    done
    echo "${list}"
}

# ─── Show Summary ─────────────────────────────────────────────────────────────
show_selection_summary() {
    print_header "Selection Summary"
    local current_cat=""
    local total=0
    local i
    for (( i=0; i<${#SVC_NAMES[@]}; i++ )); do
        local name="${SVC_NAMES[$i]}"
        if [[ -n "${SELECTED[$name]+x}" && "${SELECTED[$name]}" -eq 1 ]]; then
            local cat="${SVC_CATEGORY[$i]}"
            if [[ "${cat}" != "${current_cat}" ]]; then
                current_cat="${cat}"
                echo -e "  ${BOLD}${YELLOW}${cat^^}${RESET}"
            fi
            echo -e "    ${GREEN}✓${RESET} ${SVC_DISPLAY[$i]}"
            (( total++ )) || true
        fi
    done

    if [[ "${total}" -eq 0 ]]; then
        print_warn "No services selected."
        return 1
    fi

    echo ""
    print_info "Total: ${total} service(s) selected"
    return 0
}

# ─── Prompt Confirmation ──────────────────────────────────────────────────────
confirm() {
    local prompt="${1:-Continue?}"
    local answer
    read -r -p "$(echo -e "${BOLD}${prompt}${RESET} [y/N] ")" answer
    [[ "${answer}" =~ ^[Yy]$ ]]
}

# ─── Optional Extras ─────────────────────────────────────────────────────────
offer_reverse_proxy() {
    echo ""
    if ! confirm "Generate reverse proxy configuration?"; then
        return
    fi
    echo "Available backends: godoxy, traefik, caddy"
    local backend
    read -r -p "$(echo -e "${BOLD}Backend${RESET} [godoxy]: ")" backend
    backend="${backend:-godoxy}"

    print_info "Running reverse proxy configurator (backend: ${backend})..."
    local domain_arg=()
    if [[ -n "${BASE_DOMAIN:-}" ]]; then
        domain_arg=(--domain "${BASE_DOMAIN}")
    fi
    if bash "${SCRIPT_DIR}/reverse-proxy-configurator.sh" \
        --backend "${backend}" "${domain_arg[@]+${domain_arg[@]}}"; then
        print_success "Reverse proxy configuration generated."
    else
        print_error "Reverse proxy configuration failed."
    fi
}

offer_dependency_graph() {
    echo ""
    if ! confirm "Generate dependency graph?"; then
        return
    fi
    print_info "Running dependency graph generator..."
    if bash "${SCRIPT_DIR}/generate-dependency-graph.sh"; then
        print_success "Dependency graph generated in: ${REPO_ROOT}/graphs/"
    else
        print_error "Dependency graph generation failed."
    fi
}

# ─── Parse User Input ─────────────────────────────────────────────────────────
parse_input() {
    local input="$1"
    local total=${#SVC_NAMES[@]}

    # Trim whitespace
    input="${input#"${input%%[![:space:]]*}"}"
    input="${input%"${input##*[![:space:]]}"}"

    case "${input,,}" in
        done|proceed|go)
            return 0  # Signal: done
            ;;
        quit|exit|q)
            echo ""
            print_info "Exiting without generating anything."
            exit 0
            ;;
        all)
            select_all
            return 1
            ;;
        clear|none)
            clear_all
            return 1
            ;;
        recommended)
            select_recommended
            return 1
            ;;
        cat:*)
            local cat_name="${input#cat:}"
            select_category "${cat_name}"
            return 1
            ;;
        "")
            return 1
            ;;
    esac

    # Parse numbers, ranges, and service names
    local token
    local IFS_BACKUP="${IFS}"
    IFS=' ,;' read -ra tokens <<< "${input}"
    IFS="${IFS_BACKUP}"

    for token in "${tokens[@]}"; do
        [[ -z "${token}" ]] && continue

        if [[ "${token}" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            # Range: e.g., 2-8
            local start="${BASH_REMATCH[1]}"
            local end="${BASH_REMATCH[2]}"
            if (( start < 1 || end > total || start > end )); then
                print_warn "Invalid range: ${token} (valid: 1-${total})"
                continue
            fi
            local j
            for (( j=start; j<=end; j++ )); do
                toggle_service "${SVC_NAMES[$(( j-1 ))]}"
            done
        elif [[ "${token}" =~ ^[0-9]+$ ]]; then
            # Single number
            if (( token < 1 || token > total )); then
                print_warn "Invalid number: ${token} (valid: 1-${total})"
                continue
            fi
            toggle_service "${SVC_NAMES[$(( token-1 ))]}"
        else
            # Try as service name
            local ltoken="${token,,}"
            if [[ -n "${NAME_TO_IDX[$ltoken]+x}" ]]; then
                toggle_service "${ltoken}"
            else
                print_warn "Unknown: '${token}' — enter a number (1-${total}), range, service name, 'all', 'clear', 'cat:<name>', 'recommended', 'done', or 'quit'"
            fi
        fi
    done

    return 1
}

# ─── Interactive Selection Loop ───────────────────────────────────────────────
run_interactive() {
    while true; do
        display_menu
        local user_input
        echo -n -e "${BOLD}${CYAN}Selection>${RESET} "
        read -r user_input

        if parse_input "${user_input}"; then
            # "done" was entered — break out of loop
            break
        fi
        # Brief pause so any warnings are visible before redraw
        sleep 0.3
    done
}

# ─── Non-interactive Mode ─────────────────────────────────────────────────────
run_non_interactive() {
    local services_arg="$1"
    print_info "Non-interactive mode — selecting: ${services_arg}"

    local IFS=','
    local svc
    for svc in ${services_arg}; do
        svc="${svc// /}"
        if [[ "${svc}" == "all" ]]; then
            select_all
        elif [[ -n "${NAME_TO_IDX[$svc]+x}" ]]; then
            SELECTED["${svc}"]=1
        else
            print_warn "Unknown service in --services list: ${svc}"
        fi
    done
}

# ─── Final Output Summary ────────────────────────────────────────────────────
print_final_summary() {
    print_header "Generation Complete"

    echo -e "  ${BOLD}Files generated:${RESET}"

    [[ -f "${OUTPUT_ENV}" ]]  && echo -e "    ${GREEN}✓${RESET} ${OUTPUT_ENV}"

    local stack_file
    for stack_file in "${STACKS_DIR}"/*.yaml "${STACKS_DIR}"/*.yml; do
        [[ -f "${stack_file}" ]] && echo -e "    ${GREEN}✓${RESET} ${stack_file}"
    done

    local graph_file
    for graph_file in "${REPO_ROOT}/graphs"/*.dot; do
        [[ -f "${graph_file}" ]] && echo -e "    ${GREEN}✓${RESET} ${graph_file}"
    done

    local doc_file
    for doc_file in "${REPO_ROOT}/docs"/PROXY-SETUP.md "${REPO_ROOT}/docs"/STARTUP_PLAN.md; do
        [[ -f "${doc_file}" ]] && echo -e "    ${GREEN}✓${RESET} ${doc_file}"
    done

    echo ""
    print_info "Next steps:"
    echo "  1. Edit ${OUTPUT_ENV} only — set BASE_DOMAIN, DOCKER_DATA, passwords, and optional PORT_* overrides"
    echo "  2. Run: docker compose -f stacks/combined-stack.yaml up -d"
    echo ""
}

# ─── Argument Parsing ────────────────────────────────────────────────────────
NON_INTERACTIVE=0
NON_INTERACTIVE_SERVICES=""

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --non-interactive|-n)
                NON_INTERACTIVE=1
                shift
                ;;
            --services|-s)
                shift
                NON_INTERACTIVE_SERVICES="${1:-}"
                shift
                ;;
            --services=*)
                NON_INTERACTIVE_SERVICES="${1#*=}"
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--non-interactive --services svc1,svc2,...]"
                echo ""
                echo "Options:"
                echo "  --non-interactive, -n     Skip interactive menu"
                echo "  --services, -s <list>     Comma-separated service names (or 'all')"
                echo "  --help, -h                Show this help"
                exit 0
                ;;
            *)
                print_warn "Unknown argument: $1"
                shift
                ;;
        esac
    done
}

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"

    print_header "Server Setup Script"
    print_info "Checking dependencies..."
    check_dependencies

    print_info "Loading service registry..."
    load_registry
    print_success "Loaded ${#SVC_NAMES[@]} services from registry."

    if [[ "${NON_INTERACTIVE}" -eq 1 ]]; then
        if [[ -z "${NON_INTERACTIVE_SERVICES}" ]]; then
            print_error "--non-interactive requires --services <list>"
            exit 1
        fi
        run_non_interactive "${NON_INTERACTIVE_SERVICES}"
    else
        run_interactive
    fi

    # Resolve dependencies before showing summary
    resolve_dependencies

    if ! show_selection_summary; then
        print_warn "No services selected. Nothing to generate."
        exit 0
    fi

    if [[ "${NON_INTERACTIVE}" -eq 0 ]]; then
        echo ""
        if ! confirm "Proceed with generating files for the above services?"; then
            print_info "Aborted. No files were changed."
            exit 0
        fi
    fi

    # Generate .env
    generate_env

    # Detect port conflicts (informational only)
    detect_port_conflicts

    # Generate stacks
    generate_stacks

    # Optional extras (interactive only)
    if [[ "${NON_INTERACTIVE}" -eq 0 ]]; then
        offer_reverse_proxy
        offer_dependency_graph
    fi

    print_final_summary
}

main "$@"
