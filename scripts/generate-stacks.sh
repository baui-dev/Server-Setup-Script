#!/usr/bin/env bash
# =============================================================================
# GENERATE STACKS
# =============================================================================
# Merge selected service YAML files into per-category and combined Docker
# Compose stack files.  Reads registry/services.json to locate service files,
# extracts each service's compose block, and writes merged output to
# stacks/<category>-stack.yaml and stacks/combined-stack.yaml.
#
# Dependencies: bash ≥4, jq, awk, sed
#
# Usage:
#   bash scripts/generate-stacks.sh --services jellyfin,sonarr,radarr
#   bash scripts/generate-stacks.sh --selection-file path/to/selected.txt
#   bash scripts/generate-stacks.sh --services all --output-dir stacks/
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REGISTRY="${REPO_ROOT}/registry/services.json"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

die()  { echo -e "${RED}ERROR:${RESET} $*" >&2; exit 1; }
warn() { echo -e "${YELLOW}WARNING:${RESET} $*" >&2; }
info() { echo -e "${CYAN}  →${RESET} $*"; }

# ─── Arg parsing ─────────────────────────────────────────────────────────────
SERVICES_ARG=""
SELECTION_FILE=""
OUTPUT_DIR="${REPO_ROOT}/stacks"

usage() {
    grep '^#' "${BASH_SOURCE[0]}" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --services)        SERVICES_ARG="$2";      shift 2 ;;
        --selection-file)  SELECTION_FILE="$2";    shift 2 ;;
        --output-dir)      OUTPUT_DIR="$2";        shift 2 ;;
        -h|--help)         usage ;;
        *) die "Unknown argument: $1" ;;
    esac
done

[[ -z "${SERVICES_ARG}" && -z "${SELECTION_FILE}" ]] && \
    die "Provide --services NAME[,NAME…] or --selection-file FILE"

# ─── Dependency check ────────────────────────────────────────────────────────
command -v jq  &>/dev/null || die "jq is required. Install: sudo apt install jq"
[[ -f "${REGISTRY}" ]] || die "Registry not found: ${REGISTRY}"
mkdir -p "${OUTPUT_DIR}"

# ─── Resolve requested service names ─────────────────────────────────────────
declare -a REQUESTED=()

if [[ -n "${SERVICES_ARG}" ]]; then
    if [[ "${SERVICES_ARG,,}" == "all" ]]; then
        while IFS= read -r n; do REQUESTED+=("$n"); done \
            < <(jq -r '.services[].name' "${REGISTRY}")
    else
        IFS=',' read -ra REQUESTED <<< "${SERVICES_ARG}"
    fi
elif [[ -n "${SELECTION_FILE}" ]]; then
    [[ -f "${SELECTION_FILE}" ]] || die "Selection file not found: ${SELECTION_FILE}"
    while IFS= read -r line; do
        line="${line%%#*}"; line="${line//[[:space:]]/}"
        [[ -n "${line}" ]] && REQUESTED+=("${line}")
    done < "${SELECTION_FILE}"
fi

[[ ${#REQUESTED[@]} -eq 0 ]] && die "No services selected."

# Deterministic order: trim blanks, unique, sort.
declare -a REQUESTED_CLEAN=()
for n in "${REQUESTED[@]}"; do
    n="${n//[[:space:]]/}"
    [[ -n "${n}" ]] && REQUESTED_CLEAN+=("${n}")
done
mapfile -t REQUESTED < <(printf '%s\n' "${REQUESTED_CLEAN[@]}" | sort -u)

# ─── Extract service block from a YAML file ──────────────────────────────────
# Returns everything indented below the top-level `services:` key, stopping at
# the next unindented key (networks:, volumes:, version:).
extract_services_block() {
    local file="$1"
    awk '
        /^services:[[:space:]]*$/ { in_block=1; next }
        in_block && /^[a-zA-Z]/ { exit }
        in_block { print }
    ' "${file}"
}

# ─── Track used host ports for conflict resolution ────────────────────────────
declare -A USED_PORTS=()

# Shift a port string like "${PORT_FOO:-8080}" or "8080" until not in USED_PORTS.
# Prints the (possibly shifted) port binding line.
resolve_port_line() {
    local line="$1"
    # Match "- <host_part>:<container_part>", host part may be ${VAR:-NNNN}
    if [[ "${line}" =~ :-([0-9]+)\}:([0-9]+) ]]; then
        local base="${BASH_REMATCH[1]}"
        local candidate="${base}"
        while [[ -n "${USED_PORTS[$candidate]+x}" ]]; do
            candidate=$(( candidate + 1 ))
        done
        USED_PORTS["${candidate}"]=1
        if [[ "${candidate}" -ne "${base}" ]]; then
            warn "Port conflict: shifted ${base} → ${candidate}"
            line="${line/${base}:/${candidate}:}"
        fi
    elif [[ "${line}" =~ -[[:space:]]([0-9]+):([0-9]+) ]]; then
        local host="${BASH_REMATCH[1]}"
        local candidate="${host}"
        while [[ -n "${USED_PORTS[$candidate]+x}" ]]; do
            candidate=$(( candidate + 1 ))
        done
        USED_PORTS["${candidate}"]=1
        if [[ "${candidate}" -ne "${host}" ]]; then
            warn "Port conflict: shifted ${host} → ${candidate}"
            line="${line/${host}:/${candidate}:}"
        fi
    fi
    echo "${line}"
}

# Rewrite ${PORT_FOO:-8080} to ${PORT_FOO:-${AUTO_PORT_FOO}} so users can
# configure ports entirely via generated .env.
rewrite_auto_port_fallback() {
    local line="$1"
    if [[ "${line}" =~ (\$\{(PORT_[A-Z0-9_]+):-[0-9]+\}) ]]; then
        local full_match="${BASH_REMATCH[1]}"
        local pvar="${BASH_REMATCH[2]}"
        local autovar="${pvar/PORT_/AUTO_PORT_}"
        local replacement="\${${pvar}:-\${${autovar}}}"
        line="${line/${full_match}/${replacement}}"
    fi
    echo "${line}"
}

# ─── Main merge loop ─────────────────────────────────────────────────────────
declare -A CATEGORY_SERVICES=()   # category -> accumulated service blocks (newline-sep)
declare -A CATEGORY_NAMES=()      # category -> space-sep list of svc names written
COMBINED_BLOCK=""
COMBINED_NAMES=""
n_loaded=0
n_skipped=0

echo -e "\n${BOLD}Loading registry …${RESET}"

for raw_name in "${REQUESTED[@]}"; do
    name="${raw_name//[[:space:]]/}"
    [[ -z "${name}" ]] && continue

    entry=$(jq -c --arg n "${name}" '.services[] | select(.name==$n)' "${REGISTRY}" 2>/dev/null || true)
    if [[ -z "${entry}" ]]; then
        warn "Unknown service '${name}' – skipped."
        (( n_skipped++ )) || true
        continue
    fi

    rel_path=$(jq -r '.path' <<< "${entry}")
    category=$(jq -r '.category' <<< "${entry}")
    abs_path="${REPO_ROOT}/${rel_path}"

    if [[ ! -f "${abs_path}" ]]; then
        warn "Service file not found: ${rel_path} – skipped."
        (( n_skipped++ )) || true
        continue
    fi

    info "Loading ${name} from ${rel_path}"

    # Extract and resolve port conflicts
    local_block=""
    while IFS= read -r ln; do
        ln="$(rewrite_auto_port_fallback "${ln}")"
        if [[ "${ln}" =~ ^[[:space:]]+-[[:space:]] && "${ln}" =~ : ]]; then
            ln="$(resolve_port_line "${ln}")"
        fi
        local_block+="${ln}"$'\n'
    done < <(extract_services_block "${abs_path}")

    if [[ -z "${local_block//[$'\n' ]/}" ]]; then
        warn "No 'services:' block found in ${rel_path} – skipped."
        (( n_skipped++ )) || true
        continue
    fi

    # Append source comment + block to category accumulator
    comment="  # ── ${name} (${rel_path})"
    CATEGORY_SERVICES["${category}"]+="${comment}"$'\n'"${local_block}"$'\n'
    CATEGORY_NAMES["${category}"]+=" ${name}"
    COMBINED_BLOCK+="${comment}"$'\n'"${local_block}"$'\n'
    COMBINED_NAMES+=" ${name}"
    (( n_loaded++ )) || true
done

echo ""
echo "Loaded: ${n_loaded}  Skipped: ${n_skipped}"
[[ "${n_loaded}" -eq 0 ]] && die "No valid services loaded."

# ─── Write stack file ─────────────────────────────────────────────────────────
write_stack() {
    local title="$1"
    local note="$2"
    local out="$3"
    local block="$4"
    mkdir -p "$(dirname "${out}")"
    {
        echo "# ${title}"
        echo "# Generated by scripts/generate-stacks.sh"
        [[ -n "${note}" ]] && echo "# ${note}"
        echo "#"
        echo "# Edit port variables in your .env file before deploying."
        echo "# Start: docker compose -f $(basename "${out}") up -d"
        echo ""
        echo "services:"
        echo "${block}"
    } > "${out}"
    info "Written: ${out#"${REPO_ROOT}/"}"
}

# ─── Per-category stacks ──────────────────────────────────────────────────────
echo -e "\n${BOLD}Writing category stacks …${RESET}"
mapfile -t sorted_categories < <(printf '%s\n' "${!CATEGORY_SERVICES[@]}" | sort)
for category in "${sorted_categories[@]}"; do
    out="${OUTPUT_DIR}/${category}-stack.yaml"
    note="Services:${CATEGORY_NAMES[$category]}"
    write_stack "${category^^} STACK" "${note}" "${out}" "${CATEGORY_SERVICES[$category]}"
done

# ─── Combined stack ───────────────────────────────────────────────────────────
echo -e "\n${BOLD}Writing combined stack …${RESET}"
all_cats=""
for c in "${sorted_categories[@]}"; do all_cats+=" ${c}"; done
write_stack "COMBINED STACK" "Categories:${all_cats}" \
    "${OUTPUT_DIR}/combined-stack.yaml" "${COMBINED_BLOCK}"

echo -e "\n${GREEN}Done.${RESET} ${n_loaded} service(s) merged into ${OUTPUT_DIR#"${REPO_ROOT}/"}"
