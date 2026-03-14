#!/usr/bin/env python3
"""
canonicalize.py — Migrate compose/stacks/ entries to canonical services/ layout.

Scans every YAML under compose/stacks/, identifies services not yet registered in
registry/services.json, applies env-var normalization, writes a canonical file to
services/<category>/<subcategory>/<service-name>.yaml, and appends a full entry to
registry/services.json.

Usage:
  python3 scripts/canonicalize.py              # dry-run (default, no changes)
  python3 scripts/canonicalize.py --execute    # apply changes
  python3 scripts/canonicalize.py --execute --archive-duplicates  # also move dups to archive/
"""

from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

try:
    import yaml
except ImportError:
    sys.exit("ERROR: pyyaml not installed.  Run: pip install pyyaml")

# ─── Repo layout ──────────────────────────────────────────────────────────────
REPO = Path(__file__).resolve().parent.parent
REGISTRY_PATH = REPO / "registry" / "services.json"
SERVICES_DIR = REPO / "services"
COMPOSE_STACKS_DIR = REPO / "compose" / "stacks"
ARCHIVE_DIR = REPO / "archive" / "compose-stacks"

# ─── Companion / scaffold detection ───────────────────────────────────────────
# Services whose image matches these are infrastructure companions, NOT primaries.
_COMPANION_IMG = re.compile(
    r"\b(postgres|mysql|mariadb|redis|memcached|mongo(?:db)?|elasticsearch"
    r"|clickhouse|influxdb|rabbitmq|zookeeper|kafka|etcd|valkey|nats"
    r"|pgbouncer|haproxy|nginx(?:\b)|certbot|acme-companion|step-ca"
    r"|lscr\.io/linuxserver/mariadb|lscr\.io/linuxserver/mysql)\b",
    re.I,
)
# Service keys whose name alone identifies them as companions or sub-workers.
_COMPANION_KEY = re.compile(
    r"^(?:postgres|mysql|mariadb|redis|memcached|mongo(?:db)?|elasticsearch"
    r"|clickhouse|rabbitmq|zookeeper|kafka|db|database|cache|broker|queue"
    r"|.+[-_](?:db|postgres|mysql|mariadb|redis|mongo|cache|mq"
    # Appwrite-style workers / schedulers / maintenance
    r"|worker|worker-[a-z\-]+|maintenance|schedule|schedule-[a-z\-]+"
    r"|executor|realtime|migration|meili"
    # Postal workers
    r"|cron|smtp-server|worker|dispatcher"
    # Wazuh sub-components registered as sub-service of parent
    r"|indexer|dashboard|manager"
    # Safeline sub-components
    r"|tengine|mario|fvm|svc|detector|conductor"
    # Rustdesk sub-services
    r"|hbbr|hbbs"
    # SSM sub-services
    r"|agent-proxy"
    r"))$",
    re.I,
)
# Stub/scaffold placeholder images – indicates auto-generated empty stubs.
_SCAFFOLD_IMG = re.compile(
    r"\b(baseimage-alpine|baseimage-ubuntu|scratch|hello-world|busybox"
    r"|test-image|lscr\.io/linuxserver/baseimage)",
    re.I,
)

# ─── Folder → (category, subcategory) mapping ─────────────────────────────────
# Ordered longest-prefix first so the most specific match wins.
_FOLDER_MAP: list[tuple[str, str, str]] = [
    # AI
    ("compose/stacks/ai-stacks",                              "ai",           ""),
    # SEO / marketing
    ("compose/stacks/av7-stack",                              "productivity", "seo"),
    # Communication
    ("compose/stacks/communication-stacks/mail",              "communication","mail"),
    ("compose/stacks/communication-stacks",                   "communication",""),
    # Dashboards (top-level)
    ("compose/stacks/dashboards",                             "server",       "dashboards"),
    # Development
    ("compose/stacks/dev-stack",                              "development",  ""),
    # Files — sub-categories first
    ("compose/stacks/files-stack/backup-stacks",              "files",        "backup"),
    ("compose/stacks/files-stack/cloud-stacks",               "files",        "cloud"),
    ("compose/stacks/files-stack/file-manager",               "files",        "file-manager"),
    ("compose/stacks/files-stack/file-sharing-stacks",        "files",        "sharing"),
    ("compose/stacks/files-stack/file-sync-stacks",           "files",        "sync"),
    ("compose/stacks/files-stack",                            "files",        ""),
    # Gaming
    ("compose/stacks/gaming",                                 "gaming",       ""),
    # Hardened / security
    ("compose/stacks/hardened-stack/databases",               "server",       "databases"),
    ("compose/stacks/hardened-stack/priv-share",              "files",        "privacy"),
    ("compose/stacks/hardened-stack",                         "server",       "security"),
    # Komodo (container management)
    ("compose/stacks/komodo",                                 "server",       "management"),
    # Media — sub-categories first
    ("compose/stacks/media-stacks/cine-stack",                "media",        "movies-tv"),
    ("compose/stacks/media-stacks/document-stacks",           "media",        "documents"),
    ("compose/stacks/media-stacks/image-stack",               "media",        "images"),
    ("compose/stacks/media-stacks/music-stack",               "media",        "music"),
    ("compose/stacks/media-stacks",                           "media",        "automation"),
    # Misc
    ("compose/stacks/misc-stack/files-stack",                 "files",        ""),
    ("compose/stacks/misc-stack",                             "misc",         ""),
    # Productivity — sub-categories first
    ("compose/stacks/productivity-stacks/bookmark-manager",   "productivity", "bookmarks"),
    ("compose/stacks/productivity-stacks/note-container",     "productivity", "notes"),
    ("compose/stacks/productivity-stacks/paperless-ngx",      "productivity", "documents"),
    ("compose/stacks/productivity-stacks/to-do-stacks",       "productivity", "tasks"),
    ("compose/stacks/productivity-stacks",                    "productivity", ""),
    # Server stacks — sub-directories first
    ("compose/stacks/server-dashboards",                      "server",       "dashboards"),
    ("compose/stacks/server-stacks/auth-stack",               "server",       "auth"),
    ("compose/stacks/server-stacks/automation-stacks",        "server",       "automation"),
    ("compose/stacks/server-stacks/download-stacks",          "media",        "downloads"),
    ("compose/stacks/server-stacks/network-stack",            "networking",   ""),
    ("compose/stacks/server-stacks/remote-desktop-stacks",    "server",       "remote-desktop"),
    ("compose/stacks/server-stacks/server-dashboards",        "server",       "dashboards"),
    ("compose/stacks/server-stacks/server-management",        "server",       "management"),
    ("compose/stacks/server-stacks/user-dashboards",          "server",       "dashboards"),
    ("compose/stacks/server-stacks",                          "server",       ""),
    ("compose/stacks/user-dashboards",                        "server",       "dashboards"),
    ("compose/stacks/webos-stacks",                           "server",       "webos"),
]

# ─── Helpers ──────────────────────────────────────────────────────────────────

def to_kebab(s: str) -> str:
    """Convert an arbitrary string to kebab-case."""
    s = re.sub(r"[_\s]+", "-", s)
    s = re.sub(r"([a-z])([A-Z])", r"\1-\2", s)
    s = re.sub(r"[^a-z0-9\-]", "", s.lower())
    return re.sub(r"-{2,}", "-", s).strip("-")


def get_category(rel_posix: str) -> tuple[str, str]:
    """Return (category, subcategory) for a compose/stacks/ relative path."""
    for prefix, cat, sub in _FOLDER_MAP:
        if rel_posix.startswith(prefix):
            return cat, sub
    return "misc", ""


def extract_header_meta(content: str) -> dict:
    """
    Parse top-of-file comment block for structured metadata.
    Recognises lines like:
      # TITLE
      # GitHub: <url>
      # Image: <image>
      # Docs: <url>
    """
    meta: dict = {}
    for line in content.splitlines():
        stripped = line.strip()
        if not stripped.startswith("#"):
            if stripped:  # non-blank, non-comment → end of header
                break
            continue
        body = stripped.lstrip("#").strip()
        if not body:
            continue
        if m := re.match(r"GitHub:\s+(\S+)", body, re.I):
            meta.setdefault("github", m.group(1))
        elif m := re.match(r"Image:\s+(\S+)", body, re.I):
            meta.setdefault("docker_image", re.sub(r":.*$", "", m.group(1)))
        elif m := re.match(r"Docs:\s+(\S+)", body, re.I):
            meta.setdefault("docs", m.group(1))
        elif "title" not in meta and re.match(r"[A-Z][A-Z0-9 \-_]{1,}[A-Z0-9]$", body):
            meta["title"] = body
    return meta


def normalize_env_vars(content: str) -> str:
    """
    Replace non-canonical env var names with canonical equivalents:
      ${BASE_DATA}      → ${DOCKER_DATA}
      ${DOCKER_NETWORK} → ${DEFAULT_NETWORK}
      ${DOMAIN}         → ${BASE_DOMAIN}   (only bare ${DOMAIN}, not ${MY_DOMAIN} etc.)
    """
    content = content.replace("${BASE_DATA}", "${DOCKER_DATA}")
    content = content.replace("${DOCKER_NETWORK}", "${DEFAULT_NETWORK}")
    # Only replace exact ${DOMAIN} (not ${BASE_DOMAIN}, ${MY_DOMAIN}, etc.)
    content = re.sub(r"\$\{DOMAIN\}(?![A-Z_])", "${BASE_DOMAIN}", content)
    return content


def extract_port_vars(content: str) -> list[str]:
    """Return sorted, deduplicated list of PORT_* variable names referenced in the file."""
    return sorted(set(re.findall(r"\$\{(PORT_[A-Z0-9_]+)(?::-[^}]*)?\}", content)))


def is_companion(key: str, image: str) -> bool:
    """True if this service is a database/cache/infra companion."""
    return bool(_COMPANION_IMG.search(image or "")) or bool(_COMPANION_KEY.match(key or ""))


def is_scaffold(image: str) -> bool:
    """True if this service is an auto-generated stub placeholder."""
    return bool(_SCAFFOLD_IMG.search(image or ""))


def parse_services_block(content: str) -> Optional[dict]:
    """
    Parse the YAML 'services:' mapping from raw file content.
    Shell-variable interpolations (${VAR}) are temporarily replaced so PyYAML
    can handle the otherwise invalid YAML.
    """
    safe = re.sub(r"\$\{[^}]+\}", "__VAR__", content)
    try:
        doc = yaml.safe_load(safe)
    except yaml.YAMLError:
        return None
    if isinstance(doc, dict):
        return doc.get("services") or None
    return None


def get_primary_services(services: dict) -> list[tuple[str, str]]:
    """
    Return (service_key, image) pairs for services that are the PRIMARY deployable
    service (i.e. not infra companions like postgres, redis, etc.; not stubs).

    For multi-service stacks (e.g. Appwrite, Wazuh, Postal), only the FIRST
    non-companion service is returned to produce a single canonical entry per file.
    Other services in the file are treated as stack-internal sub-services.
    """
    primaries = []
    for key, cfg in services.items():
        if not isinstance(cfg, dict):
            continue
        image = cfg.get("image", "") or ""
        if is_companion(key, image) or is_scaffold(image):
            continue
        primaries.append((key, image))
        # One canonical primary per source file — companions/workers remain inline.
        break
    return primaries


# ─── Registry helpers ──────────────────────────────────────────────────────────

def load_registry() -> dict:
    with REGISTRY_PATH.open() as f:
        return json.load(f)


def save_registry(reg: dict) -> None:
    reg["generated"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    REGISTRY_PATH.write_text(
        json.dumps(reg, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def registry_names(reg: dict) -> set[str]:
    return {s["name"] for s in reg["services"]}


# ─── Canonical path ────────────────────────────────────────────────────────────

def canonical_path(category: str, subcategory: str, name: str) -> Path:
    """Compute canonical services/ path for a given service."""
    if subcategory:
        return SERVICES_DIR / category / subcategory / f"{name}.yaml"
    return SERVICES_DIR / category / f"{name}.yaml"


# ─── Registry entry builder ────────────────────────────────────────────────────

def build_entry(
    name: str,
    image: str,
    category: str,
    subcategory: str,
    canon: Path,
    meta: dict,
    ports: list[str],
) -> dict:
    rel_path = canon.relative_to(REPO).as_posix()
    display = meta.get("title", name.replace("-", " ").title())
    description = f"Self-hosted {display}"

    # Conservative: assume exposes_http if there are any http-ish ports
    exposes_http = bool(ports) and not all(
        any(x in p for x in ("DNS", "SMTP", "IMAP", "POP", "LMTP")) for p in ports
    )

    entry: dict = {
        "name": name,
        "display_name": display,
        "category": category,
        "subcategory": subcategory or None,
        "path": rel_path,
        "description": description,
        "github": meta.get("github", ""),
        "docker_image": meta.get("docker_image", image.split(":")[0] if image else ""),
        "ports": ports,
        "requires": [],
        "exposes_http": exposes_http,
        "reverse_proxy": (
            {"preferred": "godoxy", "host": f"{name}.${{BASE_DOMAIN}}", "path": "/"}
            if exposes_http
            else None
        ),
        "healthcheck": None,
        "compatibility": {
            "architectures": ["amd64", "arm64"],
            "minimum_docker_version": "20.10",
            "requires_privileged": False,
            "conflicts_with": [],
        },
    }
    return entry


# ─── Per-file processing ───────────────────────────────────────────────────────

# Aggregate / legacy multi-service stack files that should NOT be split.
# These are top-level gluetun-wrapped stacks or old composite stacks.
_AGGREGATE_STEMS = {
    "download-stack",
    "gluetun-download-stack",
    "gluetun-stack",
    "media-stack",
}


def process_file(
    yaml_file: Path,
    reg: dict,
    known: set[str],
    dry_run: bool,
    archive_dups: bool,
    stats: dict,
    verbose: bool,
) -> None:
    rel = yaml_file.relative_to(REPO)
    rel_str = rel.as_posix()

    # Skip known aggregate/legacy stack files.
    if yaml_file.stem in _AGGREGATE_STEMS:
        stats["skipped_aggregate"] += 1
        return

    # Read raw content.
    try:
        content = yaml_file.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        print(f"  SKIP (read error): {rel_str} — {exc}")
        stats["skipped_error"] += 1
        return

    if not content.strip():
        stats["skipped_empty"] += 1
        return

    # Parse YAML services block.
    services = parse_services_block(content)
    if services is None:
        if verbose:
            print(f"  SKIP (parse fail): {rel_str}")
        stats["skipped_parse"] += 1
        return

    category, subcategory = get_category(rel_str)
    primaries = get_primary_services(services)

    if not primaries:
        if verbose:
            print(f"  SKIP (no primary): {rel_str}")
        stats["skipped_companion"] += 1
        return

    meta = extract_header_meta(content)
    all_ports = extract_port_vars(content)

    for svc_key, svc_image in primaries:
        name = to_kebab(svc_key)

        # Already registered?
        if name in known:
            stats["duplicate"] += 1
            if archive_dups and not dry_run:
                dest = ARCHIVE_DIR / rel.relative_to("compose/stacks")
                dest.parent.mkdir(parents=True, exist_ok=True)
                yaml_file.rename(dest)
                print(f"  ARCHIVED: {rel_str}")
            elif verbose:
                print(f"  DUP (skip): {name}  [{rel_str}]")
            continue

        # Canonical service file already exists without a registry entry?
        canon = canonical_path(category, subcategory, name)
        if canon.exists():
            known.add(name)
            stats["duplicate"] += 1
            if verbose:
                print(f"  DUP (canonical exists): {name}")
            continue

        # Determine which PORT_* vars belong to this primary service.
        # Prefer vars containing the service's upper-case name; fall back to all ports.
        svc_upper = name.upper().replace("-", "_")
        svc_ports = [p for p in all_ports if svc_upper in p] or all_ports

        if dry_run:
            sub_label = f"/{subcategory}" if subcategory else ""
            print(f"  [NEW] {name}  ({category}{sub_label})  →  {canon.relative_to(REPO)}")
            stats["would_add"] += 1
            known.add(name)  # prevent re-reporting for multi-primary files
        else:
            # Write canonical file (normalized content).
            canon.parent.mkdir(parents=True, exist_ok=True)
            canon.write_text(normalize_env_vars(content), encoding="utf-8")

            # Build + append registry entry.
            entry = build_entry(name, svc_image, category, subcategory, canon, meta, svc_ports)
            reg["services"].append(entry)
            known.add(name)
            print(f"  + {name}  →  {canon.relative_to(REPO)}")
            stats["added"] += 1


# ─── Entry point ──────────────────────────────────────────────────────────────

def main() -> None:
    dry_run = "--execute" not in sys.argv
    archive_dups = "--archive-duplicates" in sys.argv
    verbose = "--verbose" in sys.argv or "-v" in sys.argv

    if dry_run:
        print("DRY-RUN mode — no files will be written.  Pass --execute to apply.\n")

    reg = load_registry()
    known = registry_names(reg)

    stats: dict[str, int] = {
        "added": 0,
        "would_add": 0,
        "duplicate": 0,
        "skipped_aggregate": 0,
        "skipped_companion": 0,
        "skipped_empty": 0,
        "skipped_parse": 0,
        "skipped_error": 0,
    }

    yaml_files = sorted(COMPOSE_STACKS_DIR.rglob("*.yaml"))
    print(f"Scanning {len(yaml_files)} YAML files under compose/stacks/ …\n")

    for yf in yaml_files:
        process_file(yf, reg, known, dry_run, archive_dups, stats, verbose)

    # Persist registry (only if changes were made).
    if not dry_run and stats["added"] > 0:
        # Sort services alphabetically by name for deterministic output.
        reg["services"].sort(key=lambda s: (s["category"], s.get("subcategory") or "", s["name"]))
        save_registry(reg)
        print(f"\nRegistry saved  ({len(reg['services'])} total services)")

    key = "would_add" if dry_run else "added"
    print(f"\n{'DRY-RUN ' if dry_run else ''}Summary")
    print(f"  {'Would add' if dry_run else 'Added'}   : {stats[key]}")
    print(f"  Duplicates : {stats['duplicate']}  (already in registry or services/)")
    print(f"  Skipped (aggregate stacks) : {stats['skipped_aggregate']}")
    print(f"  Skipped (companion-only)   : {stats['skipped_companion']}")
    print(f"  Skipped (empty)            : {stats['skipped_empty']}")
    print(f"  Skipped (parse error)      : {stats['skipped_parse']}")
    print(f"  Skipped (read error)       : {stats['skipped_error']}")


if __name__ == "__main__":
    main()
