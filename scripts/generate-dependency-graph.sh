#!/usr/bin/env bash
# =============================================================================
# GENERATE DEPENDENCY GRAPH
# =============================================================================
# Visualise service dependencies as a GraphViz DOT file and produce a
# human-readable startup plan in docs/STARTUP_PLAN.md.
#
# Node shapes (reflected in DOT comments — render with graphviz if installed):
#   rectangle — HTTP-exposing services
#   diamond   — Database / cache services
#   ellipse   — All other services
#
# DOT file can be rendered with:
#   dot -Tsvg graphs/dependency-<timestamp>.dot -o graphs/dependency.svg
#
# Dependencies: bash ≥4, jq
# Optional:     graphviz (dot command) for SVG/PNG rendering
#
# Usage:
#   bash scripts/generate-dependency-graph.sh
#   bash scripts/generate-dependency-graph.sh --services jellyfin,sonarr
#   bash scripts/generate-dependency-graph.sh --output-dir graphs/
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REGISTRY="${REPO_ROOT}/registry/services.json"
GRAPHS_DIR="${REPO_ROOT}/graphs"
DOCS_DIR="${REPO_ROOT}/docs"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

die()  { echo -e "${RED}ERROR:${RESET} $*" >&2; exit 1; }
warn() { echo -e "${YELLOW}WARNING:${RESET} $*" >&2; }
info() { echo -e "${CYAN}  →${RESET} $*"; }

# ─── Arg parsing ─────────────────────────────────────────────────────────────
SERVICES_FILTER=""
OUTPUT_DIR="${GRAPHS_DIR}"

usage() {
    grep '^#' "${BASH_SOURCE[0]}" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --services)   SERVICES_FILTER="$2"; shift 2 ;;
        --output-dir) OUTPUT_DIR="$2";      shift 2 ;;
        -h|--help)    usage ;;
        *) die "Unknown argument: $1" ;;
    esac
done

# ─── Dependency check ────────────────────────────────────────────────────────
command -v jq &>/dev/null || die "jq is required. Install: sudo apt install jq"
[[ -f "${REGISTRY}" ]] || die "Registry not found: ${REGISTRY}"
mkdir -p "${OUTPUT_DIR}" "${DOCS_DIR}"

# ─── Load services ───────────────────────────────────────────────────────────
echo -e "\n${BOLD}Loading registry …${RESET}"

declare -a SVC_NAMES=()
declare -a SVC_DISPLAY=()
declare -a SVC_CATEGORY=()
declare -a SVC_DESC=()
declare -a SVC_EXPOSES_HTTP=()
declare -a SVC_REQUIRES=()

while IFS=$'\t' read -r name display category desc exposes_http requires; do
    SVC_NAMES+=("${name}")
    SVC_DISPLAY+=("${display}")
    SVC_CATEGORY+=("${category}")
    SVC_DESC+=("${desc}")
    SVC_EXPOSES_HTTP+=("${exposes_http}")
    SVC_REQUIRES+=("${requires}")
done < <(jq -r '
    .services[]
    | [
        .name,
        (.display_name // .name),
        (.category // "misc"),
        (.description // ""),
        (if .exposes_http then "true" else "false" end),
        ((.requires // []) | join(","))
      ]
    | @tsv
' "${REGISTRY}")

# Apply optional filter
if [[ -n "${SERVICES_FILTER}" ]]; then
    IFS=',' read -ra FILTER_ARR <<< "${SERVICES_FILTER}"
    declare -A FILTER_SET=()
    for f in "${FILTER_ARR[@]}"; do FILTER_SET["${f}"]=1; done

    declare -a F_NAMES=() F_DISPLAY=() F_CATEGORY=() F_DESC=() F_EXPOSES=() F_REQUIRES=()
    local i
    for (( i=0; i<${#SVC_NAMES[@]}; i++ )); do
        if [[ -n "${FILTER_SET[${SVC_NAMES[$i]}]+x}" ]]; then
            F_NAMES+=("${SVC_NAMES[$i]}")
            F_DISPLAY+=("${SVC_DISPLAY[$i]}")
            F_CATEGORY+=("${SVC_CATEGORY[$i]}")
            F_DESC+=("${SVC_DESC[$i]}")
            F_EXPOSES+=("${SVC_EXPOSES_HTTP[$i]}")
            F_REQUIRES+=("${SVC_REQUIRES[$i]}")
        fi
    done
    SVC_NAMES=("${F_NAMES[@]+"${F_NAMES[@]}"}")
    SVC_DISPLAY=("${F_DISPLAY[@]+"${F_DISPLAY[@]}"}")
    SVC_CATEGORY=("${F_CATEGORY[@]+"${F_CATEGORY[@]}"}")
    SVC_DESC=("${F_DESC[@]+"${F_DESC[@]}"}")
    SVC_EXPOSES_HTTP=("${F_EXPOSES[@]+"${F_EXPOSES[@]}"}")
    SVC_REQUIRES=("${F_REQUIRES[@]+"${F_REQUIRES[@]}"}")
fi

total="${#SVC_NAMES[@]}"
[[ "${total}" -eq 0 ]] && die "No services to graph."
echo "  Services: ${total}"

# ─── Helpers ─────────────────────────────────────────────────────────────────
dot_id() {
    # Convert service name to a DOT-safe identifier
    echo "${1//-/_}" | tr '.' '_'
}

db_keywords="postgres mysql mariadb redis mongo elastic influx db database cache memcache"
node_shape() {
    local name="${1,,}"
    for kw in ${db_keywords}; do
        [[ "${name}" == *"${kw}"* ]] && echo "diamond" && return
    done
    [[ "$2" == "true" ]] && echo "rectangle" && return
    echo "ellipse"
}

node_color() {
    case "$1" in
        diamond)   echo "#FFD700" ;;
        rectangle) echo "#87CEEB" ;;
        *)         echo "#90EE90" ;;
    esac
}

# ─── Build DOT ───────────────────────────────────────────────────────────────
build_dot() {
    local i
    echo 'digraph service_dependencies {'
    echo '    graph [rankdir=LR, fontname="Helvetica", label="Service Dependency Graph", labelloc=t, fontsize=16];'
    echo '    node [fontname="Helvetica", fontsize=11, style=filled];'
    echo '    edge [fontname="Helvetica", fontsize=10];'
    echo ''

    # Group into subgraphs by category
    declare -a CATS_SEEN=()
    declare -A CAT_DONE=()

    for (( i=0; i<total; i++ )); do
        local cat="${SVC_CATEGORY[$i]}"
        [[ -n "${CAT_DONE[$cat]+x}" ]] && continue
        CAT_DONE["${cat}"]=1
        CATS_SEEN+=("${cat}")

        local cat_id
        cat_id="$(dot_id "${cat}")"
        echo "    subgraph cluster_${cat_id} {"
        echo "        label=\"${cat^^}\";"
        echo "        style=dashed;"

        local j
        for (( j=0; j<total; j++ )); do
            [[ "${SVC_CATEGORY[$j]}" != "${cat}" ]] && continue
            local name="${SVC_NAMES[$j]}"
            local disp="${SVC_DISPLAY[$j]}"
            local exp="${SVC_EXPOSES_HTTP[$j]}"
            local desc="${SVC_DESC[$j]//\"/\\\"}"
            local sid
            sid="$(dot_id "${name}")"
            local shape
            shape="$(node_shape "${name}" "${exp}")"
            local color
            color="$(node_color "${shape}")"
            echo "        ${sid} [label=\"${disp}\", shape=${shape}, fillcolor=\"${color}\", tooltip=\"${desc}\"];"
        done

        echo "    }"
        echo ''
    done

    # Edges
    for (( i=0; i<total; i++ )); do
        local name="${SVC_NAMES[$i]}"
        local reqs="${SVC_REQUIRES[$i]}"
        [[ -z "${reqs}" ]] && continue
        local sid
        sid="$(dot_id "${name}")"
        IFS=',' read -ra REQ_ARR <<< "${reqs}"
        for req in "${REQ_ARR[@]}"; do
            [[ -z "${req}" ]] && continue
            local rid
            rid="$(dot_id "${req}")"
            echo "    ${rid} -> ${sid};"
        done
    done

    echo '}'
}

# ─── Topological sort → startup waves ─────────────────────────────────────────
# Returns waves as lines: "WAVE <n> <name1> <name2> ..."
build_waves() {
    # Build in-degree map and dependents map using associative arrays
    declare -A IN_DEG=()
    declare -A DEPS=()
    local i
    for (( i=0; i<total; i++ )); do
        local name="${SVC_NAMES[$i]}"
        IN_DEG["${name}"]=0
    done
    for (( i=0; i<total; i++ )); do
        local name="${SVC_NAMES[$i]}"
        local reqs="${SVC_REQUIRES[$i]}"
        [[ -z "${reqs}" ]] && continue
        IFS=',' read -ra REQ_ARR <<< "${reqs}"
        for req in "${REQ_ARR[@]}"; do
            [[ -z "${req}" ]] && continue
            [[ -n "${IN_DEG[$req]+x}" ]] || continue  # skip unknown deps
            IN_DEG["${name}"]=$(( ${IN_DEG["${name}"]} + 1 ))
            DEPS["${req}"]+=" ${name}"
        done
    done

    # BFS
    local wave_num=0
    local remaining="${total}"
    while [[ "${remaining}" -gt 0 ]]; do
        wave_num=$(( wave_num + 1 ))
        local wave_members=""
        for name in "${!IN_DEG[@]}"; do
            [[ "${IN_DEG[$name]}" -ne 0 ]] && continue
            wave_members+=" ${name}"
        done
        if [[ -z "${wave_members// /}" ]]; then
            # Cycle detected: dump remaining
            warn "Cycle detected in dependency graph."
            for name in "${!IN_DEG[@]}"; do
                [[ "${IN_DEG[$name]}" -gt 0 ]] && wave_members+=" ${name}"
            done
        fi
        local sorted_wave
        sorted_wave="$(echo "${wave_members}" | tr ' ' '\n' | grep -v '^$' | sort | tr '\n' ' ')"
        echo "WAVE ${wave_num} ${sorted_wave}"
        # Remove processed and decrement dependents
        for name in ${sorted_wave}; do
            unset 'IN_DEG[$name]'
            remaining=$(( remaining - 1 ))
            for dep in ${DEPS[$name]+"${DEPS[$name]}"}; do
                [[ -n "${IN_DEG[$dep]+x}" ]] || continue
                IN_DEG["${dep}"]=$(( ${IN_DEG["${dep}"]} - 1 ))
            done
        done
        [[ "${wave_num}" -gt 100 ]] && { warn "Wave limit reached — aborting."; break; }
    done
}

# ─── Build startup plan markdown ──────────────────────────────────────────────
build_plan() {
    local now
    now="$(date -u '+%Y-%m-%d')"
    local waves_output="$1"

    # Build service map for lookups
    declare -A SVC_CAT=() SVC_D=() SVC_REQ=()
    local i
    for (( i=0; i<total; i++ )); do
        SVC_CAT["${SVC_NAMES[$i]}"]="${SVC_CATEGORY[$i]}"
        SVC_D["${SVC_NAMES[$i]}"]="${SVC_DESC[$i]}"
        SVC_REQ["${SVC_NAMES[$i]}"]="${SVC_REQUIRES[$i]//,/, }"
    done

    echo "# Service Startup Plan"
    echo ""
    echo "> Generated ${now} by \`scripts/generate-dependency-graph.sh\`"
    echo ""
    echo "Start services in the order shown below. Each wave can be started in parallel."
    echo ""

    while IFS=' ' read -r wave_label wave_num rest; do
        echo "## Wave ${wave_num}"
        echo ""
        echo "| Service | Category | Description | Requires |"
        echo "|---------|----------|-------------|---------|"
        for name in ${rest}; do
            local cat="${SVC_CAT[$name]:-}"
            local desc="${SVC_D[$name]:-}"
            local reqs="${SVC_REQ[$name]:-—}"
            [[ -z "${reqs}" ]] && reqs="—"
            echo "| ${name} | ${cat} | ${desc} | ${reqs} |"
        done
        echo ""
    done <<< "${waves_output}"

    echo "## Legend"
    echo ""
    echo "| Shape     | Meaning |"
    echo "|-----------|---------|"
    echo "| Rectangle | HTTP-exposing service |"
    echo "| Diamond   | Database / cache |"
    echo "| Ellipse   | Other / background service |"
}

# ─── Run ──────────────────────────────────────────────────────────────────────
TIMESTAMP="$(date -u '+%Y%m%d-%H%M%S')"
DOT_PATH="${OUTPUT_DIR}/dependency-${TIMESTAMP}.dot"
PLAN_PATH="${DOCS_DIR}/STARTUP_PLAN.md"

echo -e "\n${BOLD}Building DOT graph …${RESET}"
build_dot > "${DOT_PATH}"
info "Written: ${DOT_PATH#"${REPO_ROOT}/"}"

if command -v dot &>/dev/null; then
    SVG_PATH="${OUTPUT_DIR}/dependency-${TIMESTAMP}.svg"
    dot -Tsvg "${DOT_PATH}" -o "${SVG_PATH}" && info "Rendered: ${SVG_PATH#"${REPO_ROOT}/"}"
else
    echo "  (graphviz not installed — skipping SVG render)"
    echo "  Render manually: dot -Tsvg ${DOT_PATH#"${REPO_ROOT}/"} -o graphs/dependency.svg"
fi

echo -e "\n${BOLD}Computing startup plan …${RESET}"
WAVES_OUTPUT="$(build_waves)"
echo "${WAVES_OUTPUT}" | while IFS=' ' read -r _ n rest; do
    echo "  Wave ${n}: ${rest}"
done

build_plan "${WAVES_OUTPUT}" > "${PLAN_PATH}"
info "Written: ${PLAN_PATH#"${REPO_ROOT}/"}"

echo -e "\n${GREEN}Done.${RESET} ${total} service(s) graphed."
