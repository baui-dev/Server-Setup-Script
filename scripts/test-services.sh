#!/usr/bin/env bash
# =============================================================================
# test-services.sh — Smoke-test Docker Compose services
# =============================================================================
#
# For each named service (or all services listed in registry/services.json):
#   1. Runs `docker compose up -d`
#   2. Waits for the container to reach a healthy / running state
#   3. Performs an HTTP health-check against the URL defined in the registry
#   4. (By default) tears the service back down
#   5. Records the result in tests/results-<timestamp>.json
#
# Usage:
#   scripts/test-services.sh jellyfin
#   scripts/test-services.sh all
#   scripts/test-services.sh jellyfin sonarr radarr --keep-running
#
# Options:
#   --keep-running   Skip docker compose down after each test
#   --timeout N      Seconds to wait for healthy status (default: 60)
#   --help           Show this help message
#
# Dependencies: docker, curl, jq (or python3 for JSON without jq)
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="${REPO_ROOT}/registry/services.json"
TESTS_DIR="${REPO_ROOT}/tests"
TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
RESULTS_FILE="${TESTS_DIR}/results-${TIMESTAMP}.json"

KEEP_RUNNING=false
TIMEOUT=60
SERVICES=()

# ── argument parsing ──────────────────────────────────────────────────────────

usage() {
    grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \?//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep-running) KEEP_RUNNING=true ;;
        --timeout)      TIMEOUT="$2"; shift ;;
        --help|-h)      usage ;;
        -*)             echo "Unknown option: $1" >&2; exit 1 ;;
        *)              SERVICES+=("$1") ;;
    esac
    shift
done

if [[ ${#SERVICES[@]} -eq 0 ]]; then
    echo "ERROR: Specify service name(s) or 'all'." >&2
    usage
fi

# ── helpers ───────────────────────────────────────────────────────────────────

log()  { echo "[$(date -u +%H:%M:%S)] $*"; }
ok()   { echo "[$(date -u +%H:%M:%S)] ✓ $*"; }
fail() { echo "[$(date -u +%H:%M:%S)] ✗ $*" >&2; }

# Portable JSON writer (uses python3 to avoid jq dependency)
json_escape() {
    python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$1"
}

require_cmd() {
    command -v "$1" &>/dev/null || { echo "ERROR: '$1' is required but not found." >&2; exit 1; }
}

require_cmd docker
require_cmd python3

# ── registry helpers ──────────────────────────────────────────────────────────

get_service_names_all() {
    python3 - <<'EOF'
import json, sys
with open("registry/services.json") as f:
    d = json.load(f)
for s in d.get("services", []):
    print(s["name"])
EOF
}

get_service_field() {
    local name="$1" field="$2"
    python3 - <<EOF
import json, sys
with open("registry/services.json") as f:
    d = json.load(f)
for s in d.get("services", []):
    if s["name"] == "${name}":
        print(s.get("${field}", ""))
        sys.exit(0)
print("")
EOF
}

get_healthcheck_url() {
    python3 - <<EOF
import json, sys
with open("registry/services.json") as f:
    d = json.load(f)
for s in d.get("services", []):
    if s["name"] == "${1}":
        print(s.get("healthcheck", {}).get("url", ""))
        sys.exit(0)
print("")
EOF
}

get_service_path() {
    python3 - <<EOF
import json, sys
with open("registry/services.json") as f:
    d = json.load(f)
for s in d.get("services", []):
    if s["name"] == "${1}":
        print(s.get("path", ""))
        sys.exit(0)
print("")
EOF
}

# ── test logic ────────────────────────────────────────────────────────────────

# Wait for a container to be running/healthy
wait_healthy() {
    local container="$1" deadline=$(( $(date +%s) + TIMEOUT ))
    log "Waiting up to ${TIMEOUT}s for ${container} to be healthy …"
    while [[ $(date +%s) -lt $deadline ]]; do
        local status
        status=$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null || echo "missing")
        local health
        health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
            "$container" 2>/dev/null || echo "missing")
        if [[ "$status" == "running" && ( "$health" == "healthy" || "$health" == "none" ) ]]; then
            ok "Container ${container} is ${status} (health: ${health})"
            return 0
        fi
        sleep 2
    done
    fail "Timed out waiting for ${container}"
    return 1
}

# HTTP health check
check_http() {
    local url="$1"
    if [[ -z "$url" ]]; then
        log "No healthcheck URL defined — skipping HTTP check."
        return 0
    fi
    log "HTTP check: ${url}"
    local http_code
    http_code=$(curl -sf -o /dev/null -w "%{http_code}" --max-time 10 "$url" || echo "000")
    if [[ "$http_code" -ge 200 && "$http_code" -lt 400 ]]; then
        ok "HTTP ${http_code} from ${url}"
        return 0
    else
        fail "HTTP ${http_code} from ${url}"
        return 1
    fi
}

# Run one service test; appends result JSON to $results array variable (passed by name)
test_service() {
    local name="$1"
    local start_ts
    start_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local status="pass"
    local error_msg=""

    log "──────────────────────────────────────────"
    log "Testing service: ${name}"

    local rel_path
    rel_path=$(cd "$REPO_ROOT" && get_service_path "$name")
    if [[ -z "$rel_path" ]]; then
        fail "Service '${name}' not found in registry."
        printf '{"name":"%s","status":"error","error":"not in registry","started":"%s"}\n' \
            "$name" "$start_ts"
        return
    fi

    local compose_file="${REPO_ROOT}/${rel_path}"
    if [[ ! -f "$compose_file" ]]; then
        fail "Compose file not found: ${compose_file}"
        printf '{"name":"%s","status":"error","error":"compose file missing","started":"%s"}\n' \
            "$name" "$start_ts"
        return
    fi

    local compose_dir
    compose_dir="$(dirname "$compose_file")"

    # Start
    log "docker compose up -d (${rel_path})"
    if ! docker compose -f "$compose_file" up -d 2>&1; then
        status="error"
        error_msg="docker compose up failed"
        fail "$error_msg"
    fi

    # Wait for healthy
    if [[ "$status" == "pass" ]]; then
        if ! wait_healthy "$name"; then
            status="fail"
            error_msg="container did not become healthy in time"
        fi
    fi

    # HTTP check
    local hc_url
    hc_url=$(cd "$REPO_ROOT" && get_healthcheck_url "$name")
    if [[ "$status" == "pass" ]]; then
        if ! check_http "$hc_url"; then
            status="fail"
            error_msg="HTTP health check failed for ${hc_url}"
        fi
    fi

    # Tear down (unless --keep-running)
    if [[ "$KEEP_RUNNING" == false ]]; then
        log "Tearing down ${name} …"
        docker compose -f "$compose_file" down --remove-orphans 2>&1 || true
    else
        log "Keeping ${name} running (--keep-running)"
    fi

    local end_ts
    end_ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    if [[ "$status" == "pass" ]]; then
        ok "PASS: ${name}"
    else
        fail "FAIL: ${name} — ${error_msg}"
    fi

    # Emit JSON result line
    printf '{"name":"%s","status":"%s","error":"%s","compose_file":"%s","healthcheck_url":"%s","started":"%s","finished":"%s"}\n' \
        "$name" "$status" "$error_msg" "$rel_path" "$hc_url" "$start_ts" "$end_ts"
}

# ── resolve service list ──────────────────────────────────────────────────────

cd "$REPO_ROOT"

ALL_NAMES=()
if [[ "${SERVICES[*]}" == "all" || " ${SERVICES[*]} " == *" all "* ]]; then
    mapfile -t ALL_NAMES < <(get_service_names_all)
else
    ALL_NAMES=("${SERVICES[@]}")
fi

if [[ ${#ALL_NAMES[@]} -eq 0 ]]; then
    echo "ERROR: No services found." >&2
    exit 1
fi

# ── run tests ─────────────────────────────────────────────────────────────────

mkdir -p "$TESTS_DIR"
log "Running tests for: ${ALL_NAMES[*]}"
log "Results → ${RESULTS_FILE}"
log "Keep running: ${KEEP_RUNNING}"
log "Timeout: ${TIMEOUT}s"
echo ""

RESULT_LINES=()
for svc in "${ALL_NAMES[@]}"; do
    line="$(test_service "$svc" 2>&1 | tee /dev/fd/2 | tail -1)" || true
    # Capture only the last line (JSON object)
    json_line="$(test_service "$svc" 3>&1 1>&2 2>&3 | tail -1 || true)"
    RESULT_LINES+=("$(test_service "$svc" 2>/dev/null | tail -1)")
done

# ── write JSON report ─────────────────────────────────────────────────────────

# Re-run tests capturing output properly
RESULT_LINES=()
for svc in "${ALL_NAMES[@]}"; do
    tmpfile=$(mktemp)
    test_service "$svc" >"$tmpfile" 2>&1
    last_line=$(tail -1 "$tmpfile")
    cat "$tmpfile"
    rm -f "$tmpfile"
    RESULT_LINES+=("$last_line")
done

# Build JSON
{
    echo "{"
    echo "  \"generated\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"keep_running\": ${KEEP_RUNNING},"
    echo "  \"timeout_seconds\": ${TIMEOUT},"
    echo "  \"results\": ["
    first=true
    for line in "${RESULT_LINES[@]}"; do
        if [[ "$first" == true ]]; then
            first=false
        else
            echo "    ,"
        fi
        echo "    ${line}"
    done
    echo "  ]"
    echo "}"
} >"$RESULTS_FILE"

log ""
log "Results written to ${RESULTS_FILE}"

# Summary
total=${#ALL_NAMES[@]}
passed=$(grep -c '"status":"pass"' "$RESULTS_FILE" || echo 0)
failed=$(( total - passed ))

echo ""
echo "══════════════════════════════════════"
echo "  Total : ${total}"
echo "  Passed: ${passed}"
echo "  Failed: ${failed}"
echo "══════════════════════════════════════"

[[ $failed -eq 0 ]]
