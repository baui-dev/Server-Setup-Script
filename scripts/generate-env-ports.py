#!/usr/bin/env python3
"""
generate-env-ports.py — Append missing PORT_* variable definitions to templates/env-template.env.

Scans all canonical service YAML files under services/, collects every ${PORT_*} reference,
then appends any PORT_* not already defined in env-template.env with a sensible default (0,
meaning Docker assigns a port), grouped by category.

Usage:
  python3 scripts/generate-env-ports.py          # dry-run: just print missing vars
  python3 scripts/generate-env-ports.py --write  # append missing vars to env-template.env
"""
from __future__ import annotations
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ENV_TEMPLATE = REPO / "templates" / "env-template.env"
SERVICES_DIR = REPO / "services"

# Known good defaults for common services (service-name → {PORT_VAR: port})
_KNOWN_DEFAULTS: dict[str, int] = {
    # AI
    "PORT_FLOWISE": 3000,
    "PORT_KHOJ": 42110,
    "PORT_OPENHANDS": 3000,
    "PORT_LOCAL_DEEP_RESEARCH": 7788,
    "PORT_OPEN_WEBUI": 3000,
    "PORT_MAGG": 3000,
    # Communication
    "PORT_POSTIZ": 3000,
    "PORT_POSTAL": 5000,
    "PORT_STALWART": 8080,
    "PORT_SIMPLEX": 5223,
    "PORT_MAILRISE": 8025,
    # Development
    "PORT_APPWRITE": 80,
    "PORT_APPSMITH": 80,
    "PORT_BYTESTASH": 5000,
    "PORT_CODER": 7080,
    "PORT_NEXTTERM": 7681,
    "PORT_RUSTPAD": 3000,
    # Files
    "PORT_ALIST": 5244,
    "PORT_ARCHIVEBOX": 8000,
    "PORT_ZIPLINE": 3000,
    "PORT_SPACEDRIVE": 8486,
    "PORT_PALMR": 3000,
    "PORT_FILERISE": 5000,
    "PORT_ENCLOSED": 8787,
    "PORT_DUPLICATI": 8200,
    "PORT_ALIST_SYNC": 8080,
    "PORT_CLOUDREVE": 5212,
    "PORT_FOXEL": 3000,
    "PORT_OPENCLOUD": 9200,
    "PORT_OXICLOUD": 3000,
    "PORT_COPYPARTY": 3923,
    "PORT_SEAFILE": 80,
    "PORT_UNISON": 5000,
    "PORT_PYDIO": 80,
    "PORT_GOKAPI": 53842,
    # Productivity
    "PORT_SERPBEAR": 3010,
    "PORT_EXCALIDRAW": 80,
    "PORT_HOARDER": 3000,
    "PORT_KARAKEEP": 3000,
    "PORT_DONETICK": 3000,
    "PORT_STIRLING_PDF": 8080,
    # Media
    "PORT_TDARR": 8265,
    "PORT_TDARR_NODE": 8266,
    "PORT_JFA_GO": 8056,
    "PORT_KYOO_BACK": 5000,
    "PORT_KYOO_FRONT": 8901,
    "PORT_PAPERLESS": 8000,
    "PORT_PAPRA": 3000,
    "PORT_IMMICH_SERVER": 3001,
    "PORT_DISPATCHARR": 6969,
    "PORT_HOMEHOST": 3000,
    "PORT_AGREGARR": 3000,
    "PORT_AIOSTREAMS": 3000,
    "PORT_PROFILARR": 6868,
    "PORT_FLEXGET": 5050,
    "PORT_JELLYFIN_VUE": 80,
    # Gaming
    "PORT_GAMEVAULT": 8080,
    "PORT_LANCOMMANDER": 1337,
    "PORT_QUESTARR": 3000,
    # Networking
    "PORT_NETDATA": 19999,
    "PORT_TIANJI": 12122,
    "PORT_ZTNET": 3000,
    "PORT_OUTLINE_SERVER": 8080,
    "PORT_HIDDIFY": 2095,
    "PORT_HEADSCALE_UI": 8080,
    "PORT_AMNEZIAWG": 51820,
    "PORT_BEEPASS": 8080,
    "PORT_ALGO": 51820,
    # Server / security
    "PORT_ALIASVAULT": 80,
    "PORT_BACKVAULT": 8080,
    "PORT_INFISICAL": 8080,
    "PORT_SAFELINE_MGT": 9443,
    "PORT_TIRRENO": 8080,
    "PORT_WAZUH_MANAGER": 55000,
    "PORT_WAZUH_DASHBOARD": 443,
    "PORT_CHARTDB": 3000,
    "PORT_CLOUDBEAVER": 8978,
    "PORT_DATASTATION": 3000,
    "PORT_DB_STUDIO": 3000,
    "PORT_CORE": 8080,
    "PORT_FERRETDB": 27017,
    "PORT_ASTROLUMA": 3000,
    "PORT_DOKPLOY": 3000,
    "PORT_1PANEL": 4004,
    "PORT_CLOUDPANEL": 8443,
    "PORT_COCKPIT": 9090,
    "PORT_CV4PVE_ADMIN": 8006,
    "PORT_KUBERO": 3000,
    "PORT_OPENPANEL": 2087,
    "PORT_SSM_CLIENT": 12230,
    "PORT_KASM": 443,
    # WebOS
    "PORT_AARONOS": 8888,
    "PORT_AROZOS": 8080,
    "PORT_KODCLOUD": 80,
    "PORT_PUTER": 4100,
    "PORT_FRIENDUP_OS": 8080,
    "PORT_WAZUHMANAGER": 55000,
    # Misc
    "PORT_CHANGE_DETECTION": 5000,
}


def collect_port_vars() -> dict[str, set[str]]:
    """Return {category: {PORT_VAR, ...}} from all canonical service files."""
    cat_ports: dict[str, set[str]] = {}
    for yf in sorted(SERVICES_DIR.rglob("*.yaml")):
        parts = yf.relative_to(SERVICES_DIR).parts
        cat = parts[0] if parts else "misc"
        content = yf.read_text(errors="replace")
        for m in re.finditer(r"\$\{(PORT_[A-Z0-9_]+)", content):
            cat_ports.setdefault(cat, set()).add(m.group(1))
    return cat_ports


def existing_vars() -> set[str]:
    return set(re.findall(r"^(PORT_[A-Z0-9_]+)=", ENV_TEMPLATE.read_text(), re.M))


def main() -> None:
    write_mode = "--write" in sys.argv

    cat_ports = collect_port_vars()
    defined = existing_vars()

    all_new: dict[str, list[str]] = {}
    for cat, ports in sorted(cat_ports.items()):
        missing = sorted(ports - defined)
        if missing:
            all_new[cat] = missing

    if not all_new:
        print("env-template.env already covers all PORT_* variables. Nothing to add.")
        return

    total = sum(len(v) for v in all_new.values())

    if not write_mode:
        print(f"DRY-RUN: {total} PORT_* vars not yet in env-template.env\n")
        for cat, ports in all_new.items():
            print(f"  # {cat.upper()}")
            for p in ports:
                default = _KNOWN_DEFAULTS.get(p, 0)
                print(f"  {p}={default}")
        print(f"\nRun with --write to append to {ENV_TEMPLATE.relative_to(REPO)}")
        return

    # Append to end of env-template.env
    append_lines: list[str] = [
        "",
        "# ── Additional Service Ports (auto-generated by scripts/generate-env-ports.py) ──",
    ]
    for cat, ports in all_new.items():
        append_lines.append(f"\n# {cat.title()}")
        for p in ports:
            default = _KNOWN_DEFAULTS.get(p, 0)
            append_lines.append(f"{p}={default}")

    current = ENV_TEMPLATE.read_text()
    ENV_TEMPLATE.write_text(current + "\n".join(append_lines) + "\n", encoding="utf-8")
    print(f"Appended {total} PORT_* variable(s) to {ENV_TEMPLATE.relative_to(REPO)}")
    for cat, ports in all_new.items():
        print(f"  [{cat}] {', '.join(ports)}")


if __name__ == "__main__":
    main()
