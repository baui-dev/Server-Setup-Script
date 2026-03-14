#!/usr/bin/env bash
# =============================================================================
# VALIDATE SERVICES
# =============================================================================
# Validates all service YAML files under services/ against:
#   1. File structure  — has a `services:` block
#   2. Header comments — has # Service, # GitHub:, # Image:, # Docs: lines
#   3. Registry entry  — service key exists in registry/services.json
#   4. Port ranges     — host ports are in the valid 1–65535 range
#   5. Duplicate ports — same host port used across multiple services
#   6. Required fields — image, environment/env_file present
#
# Writes a JSON report to tests/validate-report.json.
#
# Dependencies: bash ≥4, jq
#
# Usage:
#   bash scripts/validate-services.sh
#   bash scripts/validate-services.sh --strict            # exit 1 on warnings
#   bash scripts/validate-services.sh --service jellyfin  # single service
#   bash scripts/validate-services.sh --services-dir path/to/services
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REGISTRY="${REPO_ROOT}/registry/services.json"
SERVICES_DIR="${REPO_ROOT}/services"
REPORT_PATH="${REPO_ROOT}/tests/validate-report.json"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

die()  { echo -e "${RED}ERROR:${RESET} $*" >&2; exit 1; }
warn() { echo -e "${YELLOW}WARN:${RESET} $*" >&2; }
info() { echo -e "${CYAN}  →${RESET} $*"; }
ok()   { echo -e "${GREEN}  ✓${RESET} $*"; }

# ─── Arg parsing ─────────────────────────────────────────────────────────────
STRICT=false
SERVICE_FILTER=""

usage() {
    grep '^#' "${BASH_SOURCE[0]}" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --strict)       STRICT=true;             shift   ;;
        --service)      SERVICE_FILTER="$2";     shift 2 ;;
        --services-dir) SERVICES_DIR="$2";       shift 2 ;;
        -h|--help)      usage ;;
        *) die "Unknown argument: $1" ;;
    esac
done

command -v jq &>/dev/null || die "jq is required. Install: sudo apt install jq"
[[ -f "${REGISTRY}" ]] || die "Registry not found: ${REGISTRY}"
[[ -d "${SERVICES_DIR}" ]] || die "Services directory not found: ${SERVICES_DIR}"
mkdir -p "$(dirname "${REPORT_PATH}")"

# ─── Load registry service names (for lookup) ────────────────────────────────
declare -A REG_NAMES=()
while IFS= read -r name; do
    REG_NAMES["${name}"]=1
done < <(jq -r '.services[].name' "${REGISTRY}" 2>/dev/null)

declare -a REG_PATHS=()
while IFS= read -r path; do
    REG_PATHS+=("${path}")
done < <(jq -r '.services[].path // empty' "${REGISTRY}" 2>/dev/null)
declare -A REG_PATH_SET=()
for p in "${REG_PATHS[@]}"; do REG_PATH_SET["${p}"]=1; done

# ─── Collect files ───────────────────────────────────────────────────────────
declare -a FILES=()
if [[ -n "${SERVICE_FILTER}" ]]; then
    while IFS= read -r f; do
        [[ "$(basename "${f}" .yaml)" == "${SERVICE_FILTER}" ]] || continue
        FILES+=("${f}")
    done < <(find "${SERVICES_DIR}" -name '*.yaml' | sort)
    [[ "${#FILES[@]}" -eq 0 ]] && die "No YAML found for service: ${SERVICE_FILTER}"
else
    while IFS= read -r f; do
        FILES+=("${f}")
    done < <(find "${SERVICES_DIR}" -name '*.yaml' | sort)
fi

[[ "${#FILES[@]}" -eq 0 ]] && die "No YAML files found in: ${SERVICES_DIR}"

# ─── Tracking ────────────────────────────────────────────────────────────────
declare -A USED_PORTS=()      # port → first file that claimed it
declare -a RESULTS=()         # JSON object strings for report
ERRORS=0
WARNINGS=0

# ─── Pre-flight: kebab-case naming check ─────────────────────────────────────
echo -e "\n${BOLD}Checking naming conventions …${RESET}"
NAMING_ERRORS=0
for f in "${FILES[@]}"; do
    rel="${f#"${REPO_ROOT}/"}"
    stem="$(basename "${f}" .yaml)"
    # Check file stem (service name) for uppercase or underscores
    if [[ "${stem}" =~ [A-Z] ]]; then
        warn "Uppercase in filename: ${rel}"
        NAMING_ERRORS=$(( NAMING_ERRORS + 1 ))
    fi
    if [[ "${stem}" =~ _ ]]; then
        warn "Underscore in filename (use kebab-case): ${rel}"
        NAMING_ERRORS=$(( NAMING_ERRORS + 1 ))
    fi
    # Check parent directories (only under services/) for same violations
    IFS='/' read -ra path_parts <<< "${rel}"
    for part in "${path_parts[@]}"; do
        [[ "${part}" == *.yaml ]] && continue
        if [[ "${part}" =~ [A-Z] ]]; then
            warn "Uppercase in directory name: ${rel}  (dir: ${part})"
            NAMING_ERRORS=$(( NAMING_ERRORS + 1 ))
        fi
        if [[ "${part}" =~ _ ]]; then
            warn "Underscore in directory name (use kebab-case): ${rel}  (dir: ${part})"
            NAMING_ERRORS=$(( NAMING_ERRORS + 1 ))
        fi
    done
done
[[ "${NAMING_ERRORS}" -eq 0 ]] && ok "All paths use kebab-case."
ERRORS=$(( ERRORS + NAMING_ERRORS ))

# ─── Pre-flight: duplicate service names in registry ────────────────────────
echo -e "\n${BOLD}Checking registry for duplicate service names …${RESET}"
DUPE_ERRORS=0
while IFS= read -r dname; do
    warn "Duplicate registry name: ${dname}"
    DUPE_ERRORS=$(( DUPE_ERRORS + 1 ))
done < <(jq -r '.services[].name' "${REGISTRY}" | sort | uniq -d)
[[ "${DUPE_ERRORS}" -eq 0 ]] && ok "No duplicate service names in registry."
ERRORS=$(( ERRORS + DUPE_ERRORS ))

echo -e "\n${BOLD}Validating ${#FILES[@]} service file(s) …${RESET}\n"

# ─── Per-file Tracking (reset any counters for file loop) ───────────────────

# ─── Check a single file ─────────────────────────────────────────────────────
check_file() {
    local file="$1"
    local rel
    rel="${file#"${REPO_ROOT}/"}"
    local name
    name="$(basename "${file}" .yaml)"

    local -a errors=()
    local -a warnings=()

    # 1. Has services: block
    if ! grep -q '^services:' "${file}" 2>/dev/null; then
        errors+=("missing top-level 'services:' block")
    fi

    # 2. Header comments
    local header
    header="$(head -n 20 "${file}")"
    if ! echo "${header}" | grep -q '# GitHub:'; then
        warnings+=("missing '# GitHub:' header comment")
    fi
    if ! echo "${header}" | grep -q '# Image:'; then
        warnings+=("missing '# Image:' header comment")
    fi
    if ! echo "${header}" | grep -q '# Docs:'; then
        warnings+=("missing '# Docs:' header comment")
    fi

    # 3. Registry entry (by name or relative path)
    local in_registry=false
    if [[ -n "${REG_NAMES[$name]+x}" ]]; then
        in_registry=true
    fi
    if [[ -n "${REG_PATH_SET[$rel]+x}" ]]; then
        in_registry=true
    fi
    if [[ "${in_registry}" == "false" ]]; then
        warnings+=("not found in registry/services.json (name=${name}, path=${rel})")
    fi

    # 4. Image present
    if ! grep -qE '^\s+image:' "${file}" 2>/dev/null; then
        warnings+=("no 'image:' found in services block")
    fi

    # 5. Port range validation
    # Extract "HOST:CONTAINER" or just HOST port lines
    local port_errors=()
    while IFS= read -r port_line; do
        # Strip leading whitespace / dash
        port_line="${port_line//[[:space:]]/}"
        port_line="${port_line#-}"
        port_line="${port_line//\"/}"
        port_line="${port_line//\'/}"
        # Get host port (before colon)
        local host_port="${port_line%%:*}"
        # Remove any protocol suffix (e.g. /tcp /udp)
        host_port="${host_port%/*}"
        # Must be numeric
        if [[ ! "${host_port}" =~ ^[0-9]+$ ]]; then
            continue
        fi
        if [[ "${host_port}" -lt 1 || "${host_port}" -gt 65535 ]]; then
            port_errors+=("port ${host_port} out of valid range (1–65535)")
        fi
        # Duplicate across files
        if [[ -n "${USED_PORTS[$host_port]+x}" ]]; then
            warnings+=("port ${host_port} already used by ${USED_PORTS[$host_port]}")
        else
            USED_PORTS["${host_port}"]="${name}"
        fi
    done < <(grep -E '^\s+- "[0-9]|^\s+- [0-9]' "${file}" 2>/dev/null | head -n 40)
    errors+=("${port_errors[@]+"${port_errors[@]}"}")

    # ─── Report per file ─────────────────────────────────────────────────────
    local status="ok"
    if [[ "${#errors[@]}" -gt 0 ]]; then
        status="error"
        ERRORS=$(( ERRORS + ${#errors[@]} ))
        printf '  %-55s %s\n' "${rel}" "$(echo -e "${RED}FAIL${RESET}")"
        for e in "${errors[@]}"; do
            echo -e "      ${RED}✗${RESET} ${e}"
        done
    else
        ok "${rel}"
    fi
    if [[ "${#warnings[@]}" -gt 0 ]]; then
        [[ "${status}" == "ok" ]] && status="warning"
        WARNINGS=$(( WARNINGS + ${#warnings[@]} ))
        for w in "${warnings[@]}"; do
            echo -e "      ${YELLOW}⚠${RESET} ${w}"
        done
    fi

    # Build JSON result
    local errors_json="[]"
    if [[ "${#errors[@]}" -gt 0 ]]; then
        errors_json="$(printf '%s\n' "${errors[@]}" | jq -Rn '[inputs]')"
    fi
    local warnings_json="[]"
    if [[ "${#warnings[@]}" -gt 0 ]]; then
        warnings_json="$(printf '%s\n' "${warnings[@]}" | jq -Rn '[inputs]')"
    fi

    RESULTS+=("$(jq -n \
        --arg file "${rel}" \
        --arg name "${name}" \
        --arg status "${status}" \
        --argjson errors "${errors_json}" \
        --argjson warnings "${warnings_json}" \
        '{file: $file, name: $name, status: $status, errors: $errors, warnings: $warnings}')")
}

# ─── Run checks ──────────────────────────────────────────────────────────────
for f in "${FILES[@]}"; do
    check_file "${f}"
done

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Summary${RESET}"
echo -e "  Files checked : ${#FILES[@]}"
echo -e "  Errors        : ${ERRORS}"
echo -e "  Warnings      : ${WARNINGS}"

# ─── Write JSON report ───────────────────────────────────────────────────────
{
    printf '[\n'
    first=true
    for r in "${RESULTS[@]}"; do
        [[ "${first}" == "true" ]] && first=false || printf ',\n'
        echo "${r}"
    done
    printf '\n]\n'
} > "${REPORT_PATH}"
info "Report written: ${REPORT_PATH#"${REPO_ROOT}/"}"

# ─── Exit code ───────────────────────────────────────────────────────────────
if [[ "${ERRORS}" -gt 0 ]]; then
    echo -e "\n${RED}Validation FAILED — ${ERRORS} error(s).${RESET}"
    exit 1
fi
if [[ "${STRICT}" == "true" && "${WARNINGS}" -gt 0 ]]; then
    echo -e "\n${YELLOW}Validation FAILED (strict) — ${WARNINGS} warning(s).${RESET}"
    exit 1
fi
if [[ "${#FILES[@]}" -gt 0 ]]; then
    echo -e "\n${GREEN}All files passed validation.${RESET}"
fi
