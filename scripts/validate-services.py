#!/usr/bin/env python3
"""
validate-services.py — Validate all service YAML files in services/ against
quality and consistency rules.

Checks performed for each YAML file:
  1. YAML is parseable (syntax check)
  2. Required metadata header comments are present (SERVICE NAME, GitHub,
     Image, Docs)
  3. A matching entry exists in registry/services.json
  4. All port bindings use values in the valid range 1–65535
  5. No duplicate service keys exist across all files
  6. `exposes_http` in the registry is consistent with the presence of HTTP
     ports in the compose file

Outputs a human-readable summary to stdout and a machine-readable report to
tests/validate-report.json.

Usage:
    python3 scripts/validate-services.py
    python3 scripts/validate-services.py --strict   # exit 1 on any warning
    python3 scripts/validate-services.py --fix-registry  # add missing stubs
"""

import argparse
import json
import os
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML is required. Install it with: pip install pyyaml", file=sys.stderr)
    sys.exit(1)


REPO_ROOT = Path(__file__).resolve().parent.parent
SERVICES_DIR = REPO_ROOT / "services"
REGISTRY_PATH = REPO_ROOT / "registry" / "services.json"
REPORT_DIR = REPO_ROOT / "tests"
REPORT_PATH = REPORT_DIR / "validate-report.json"

# Header comment fields that must appear in every service YAML
REQUIRED_HEADER_FIELDS = ["# ", "# GitHub:", "# Image:", "# Docs:"]

# HTTP ports (container side) — used to infer whether a service exposes HTTP
HTTP_PORTS = {80, 443, 8080, 8443, 3000, 5000, 8000, 8888, 9000}


# ── helpers ──────────────────────────────────────────────────────────────────


def load_registry() -> dict:
    """Load services registry; return empty dict if missing."""
    if not REGISTRY_PATH.exists():
        return {}
    with open(REGISTRY_PATH) as f:
        data = json.load(f)
    return {s["name"]: s for s in data.get("services", [])}


def find_yaml_files() -> list[Path]:
    """Recursively collect all .yaml files under services/."""
    return sorted(SERVICES_DIR.rglob("*.yaml"))


def parse_yaml(path: Path) -> tuple[dict | None, str | None]:
    """Return (parsed_dict, error_message). error_message is None on success."""
    try:
        with open(path) as f:
            content = f.read()
        parsed = yaml.safe_load(content)
        return parsed or {}, None
    except yaml.YAMLError as exc:
        return None, str(exc)


def read_raw_header(path: Path, lines: int = 10) -> str:
    """Return the first `lines` lines of a file as a single string."""
    try:
        with open(path) as f:
            return "".join(f.readline() for _ in range(lines))
    except OSError:
        return ""


def extract_ports(service_def: dict) -> list[int]:
    """
    Extract all container-side port numbers from a service definition.
    Returns list of ints.
    """
    ports = []
    for entry in service_def.get("ports", []):
        entry_str = str(entry)
        # Handle host:container and bare container formats
        parts = entry_str.split(":")
        container_part = parts[-1].split("/")[0]  # strip /udp etc.
        # Strip variable references
        container_part = re.sub(r"\$\{[^}]+\}", "", container_part).strip()
        if container_part.isdigit():
            ports.append(int(container_part))
    return ports


def port_in_range(port: int) -> bool:
    return 1 <= port <= 65535


def check_header(path: Path) -> list[str]:
    """Return list of missing header field descriptions."""
    header = read_raw_header(path)
    missing = []
    if not re.search(r"^# [A-Z]", header, re.MULTILINE):
        missing.append("SERVICE NAME comment (e.g. '# JELLYFIN')")
    for field in ["# GitHub:", "# Image:", "# Docs:"]:
        if field not in header:
            missing.append(field)
    return missing


# ── per-file validation ───────────────────────────────────────────────────────


def validate_file(
    path: Path, registry: dict, all_service_keys: dict
) -> dict:
    """
    Validate a single YAML file.

    Returns a result dict with keys: path, errors, warnings, service_names.
    """
    rel = str(path.relative_to(REPO_ROOT))
    result = {
        "path": rel,
        "errors": [],
        "warnings": [],
        "service_names": [],
        "registry_name": None,
    }

    # 1. YAML syntax
    parsed, err = parse_yaml(path)
    if err:
        result["errors"].append(f"YAML parse error: {err}")
        return result

    # 2. Header comments
    missing_headers = check_header(path)
    for mh in missing_headers:
        result["warnings"].append(f"Missing header field: {mh}")

    svc_block = parsed.get("services", {})
    if not svc_block:
        result["warnings"].append("No 'services:' block found")
        return result

    result["service_names"] = list(svc_block.keys())

    # 5. Duplicate service keys (across all files)
    for key in svc_block:
        if key in all_service_keys and all_service_keys[key] != rel:
            result["errors"].append(
                f"Duplicate service key '{key}' also defined in {all_service_keys[key]}"
            )
        else:
            all_service_keys[key] = rel

    # 3. Registry entry
    # Try to match by service name (key in compose) or by path
    matched_entry = None
    for key in svc_block:
        if key in registry:
            matched_entry = registry[key]
            result["registry_name"] = key
            break
    if matched_entry is None:
        # Try by path
        for reg_entry in registry.values():
            if reg_entry.get("path", "") == rel:
                matched_entry = reg_entry
                result["registry_name"] = reg_entry["name"]
                break
    if matched_entry is None:
        result["warnings"].append("No matching entry found in registry/services.json")

    # 4. Port range validation + 6. exposes_http consistency
    for svc_key, svc_def in svc_block.items():
        container_ports = extract_ports(svc_def)
        for cp in container_ports:
            if not port_in_range(cp):
                result["errors"].append(
                    f"Service '{svc_key}': container port {cp} is out of valid range 1–65535"
                )

        # exposes_http check
        if matched_entry is not None:
            reg_http = matched_entry.get("exposes_http", False)
            has_http_port = bool(set(container_ports) & HTTP_PORTS)
            if reg_http and not has_http_port:
                result["warnings"].append(
                    f"Service '{svc_key}': registry says exposes_http=true but no "
                    f"common HTTP port found in compose (checked: {sorted(HTTP_PORTS)})"
                )
            elif not reg_http and has_http_port:
                result["warnings"].append(
                    f"Service '{svc_key}': registry says exposes_http=false but HTTP-like "
                    f"port {set(container_ports) & HTTP_PORTS} found in compose"
                )

    return result


# ── report helpers ────────────────────────────────────────────────────────────


def print_report(results: list[dict], elapsed_s: float) -> None:
    """Print a human-readable report to stdout."""
    total = len(results)
    n_ok = sum(1 for r in results if not r["errors"] and not r["warnings"])
    n_warn = sum(1 for r in results if r["warnings"] and not r["errors"])
    n_err = sum(1 for r in results if r["errors"])

    print()
    print("=" * 70)
    print("  SERVICE YAML VALIDATION REPORT")
    print(f"  {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}")
    print("=" * 70)

    for r in results:
        status = "✓" if not r["errors"] else "✗"
        warn_str = f"  [{len(r['warnings'])} warning(s)]" if r["warnings"] else ""
        print(f"\n  {status} {r['path']}{warn_str}")
        for e in r["errors"]:
            print(f"      ERROR:   {e}")
        for w in r["warnings"]:
            print(f"      WARNING: {w}")

    print()
    print("─" * 70)
    print(f"  Files checked : {total}")
    print(f"  Passed        : {n_ok}")
    print(f"  Warnings      : {n_warn}")
    print(f"  Errors        : {n_err}")
    print(f"  Time          : {elapsed_s:.2f}s")
    print("─" * 70)
    if n_err == 0 and n_warn == 0:
        print("  All checks passed!")
    elif n_err == 0:
        print("  No errors. Some warnings to review.")
    else:
        print(f"  {n_err} file(s) have errors that must be fixed.")
    print()


def write_json_report(results: list[dict], elapsed_s: float) -> None:
    """Write machine-readable JSON report to tests/validate-report.json."""
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    report = {
        "generated": datetime.now(timezone.utc).isoformat(),
        "summary": {
            "total": len(results),
            "passed": sum(1 for r in results if not r["errors"] and not r["warnings"]),
            "with_warnings": sum(1 for r in results if r["warnings"] and not r["errors"]),
            "with_errors": sum(1 for r in results if r["errors"]),
            "elapsed_seconds": round(elapsed_s, 3),
        },
        "results": results,
    }
    with open(REPORT_PATH, "w") as f:
        json.dump(report, f, indent=2)
    print(f"JSON report written to {REPORT_PATH.relative_to(REPO_ROOT)}")


# ── entry point ───────────────────────────────────────────────────────────────


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate service YAML files for syntax, metadata, and consistency.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit with code 1 if any warnings are found (in addition to errors).",
    )
    parser.add_argument(
        "--service",
        metavar="NAME",
        help="Validate only the named service file (matches by filename stem).",
    )
    return parser.parse_args()


def main() -> None:
    import time

    args = parse_args()
    start = time.monotonic()

    print(f"Scanning {SERVICES_DIR.relative_to(REPO_ROOT)} …")
    yaml_files = find_yaml_files()

    if args.service:
        yaml_files = [f for f in yaml_files if f.stem == args.service]
        if not yaml_files:
            print(f"ERROR: No YAML file found with stem '{args.service}'", file=sys.stderr)
            sys.exit(1)

    print(f"Found {len(yaml_files)} YAML file(s). Loading registry …")
    registry = load_registry()
    print(f"Registry has {len(registry)} service(s).\n")

    all_service_keys: dict = {}  # key → first file that defined it
    results = []

    for path in yaml_files:
        res = validate_file(path, registry, all_service_keys)
        results.append(res)

    elapsed = time.monotonic() - start
    print_report(results, elapsed)
    write_json_report(results, elapsed)

    n_err = sum(1 for r in results if r["errors"])
    n_warn = sum(1 for r in results if r["warnings"])

    if n_err > 0:
        sys.exit(1)
    if args.strict and n_warn > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
