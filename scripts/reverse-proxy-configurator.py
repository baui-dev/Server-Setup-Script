#!/usr/bin/env python3
"""
reverse-proxy-configurator.py — Generate reverse proxy configuration for
services that expose HTTP, based on registry/services.json.

Supports three backends:
  godoxy  — Docker labels (go-doxy compatible)
  traefik — Docker labels + dynamic config YAML
  caddy   — Caddyfile snippet per service

Output files:
  stacks/proxy-<backend>.yaml   (Docker Compose with labels / Caddyfile)
  docs/PROXY-SETUP.md           (human-readable setup guide)

Usage:
    python3 scripts/reverse-proxy-configurator.py --backend godoxy
    python3 scripts/reverse-proxy-configurator.py --backend traefik --domain example.com
    python3 scripts/reverse-proxy-configurator.py --backend caddy
"""

import argparse
import json
import os
import sys
from pathlib import Path
from datetime import datetime, timezone

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML is required. Install it with: pip install pyyaml", file=sys.stderr)
    sys.exit(1)

REPO_ROOT = Path(__file__).resolve().parent.parent
REGISTRY_PATH = REPO_ROOT / "registry" / "services.json"
STACKS_DIR = REPO_ROOT / "stacks"
DOCS_DIR = REPO_ROOT / "docs"

BACKENDS = ["godoxy", "traefik", "caddy"]


# ── Registry ─────────────────────────────────────────────────────────────────


def load_http_services(domain: str) -> list[dict]:
    """Return registry entries where exposes_http is True."""
    if not REGISTRY_PATH.exists():
        print(f"ERROR: Registry not found at {REGISTRY_PATH}", file=sys.stderr)
        sys.exit(1)
    with open(REGISTRY_PATH) as f:
        data = json.load(f)
    services = [s for s in data.get("services", []) if s.get("exposes_http")]
    # Resolve domain placeholder
    for svc in services:
        rp = svc.get("reverse_proxy", {})
        if "host" in rp:
            rp["host"] = rp["host"].replace("${BASE_DOMAIN}", domain)
    return services


# ── godoxy ───────────────────────────────────────────────────────────────────


def godoxy_labels(svc: dict, domain: str) -> dict:
    """Return godoxy Docker labels for a service."""
    name = svc["name"]
    host = svc.get("reverse_proxy", {}).get("host", f"{name}.{domain}")
    hc = svc.get("healthcheck", {})
    port = ""
    if hc.get("url"):
        # Extract port from healthcheck URL
        import re
        m = re.search(r":(\d+)", hc["url"])
        if m:
            port = m.group(1)

    labels = {
        "proxy.host": host,
        "proxy.port": port,
        "proxy.scheme": "http",
    }
    return {f"proxy.{k}" if not k.startswith("proxy.") else k: v for k, v in labels.items()}


def generate_godoxy(services: list[dict], domain: str) -> dict:
    """Build a Docker Compose dict with godoxy labels for each HTTP service."""
    compose_services = {}
    for svc in services:
        name = svc["name"]
        host = svc.get("reverse_proxy", {}).get("host", f"{name}.{domain}")
        hc = svc.get("healthcheck", {})
        port = ""
        if hc.get("url"):
            import re
            m = re.search(r":(\d+)", hc["url"])
            if m:
                port = m.group(1)

        labels = {
            "proxy.host": host,
            "proxy.port": port,
            "proxy.scheme": "http",
        }
        compose_services[name] = {
            "# Source": f"registry entry for {name}",
            "extends": {
                "file": f"../{svc.get('path', f'services/{name}.yaml')}",
                "service": name,
            },
            "labels": labels,
            "networks": ["${DEFAULT_NETWORK}"],
        }

    return {
        "version": "3.8",
        "services": compose_services,
        "networks": {
            "${DEFAULT_NETWORK}": {"external": True}
        },
    }


# ── traefik ──────────────────────────────────────────────────────────────────


def traefik_labels(svc: dict, domain: str) -> dict:
    """Return Traefik v2/v3 Docker labels for a service."""
    name = svc["name"]
    host = svc.get("reverse_proxy", {}).get("host", f"{name}.{domain}")
    hc = svc.get("healthcheck", {})
    port = "80"
    if hc.get("url"):
        import re
        m = re.search(r":(\d+)", hc["url"])
        if m:
            port = m.group(1)

    return {
        "traefik.enable": "true",
        f"traefik.http.routers.{name}.rule": f"Host(`{host}`)",
        f"traefik.http.routers.{name}.entrypoints": "websecure",
        f"traefik.http.routers.{name}.tls.certresolver": "letsencrypt",
        f"traefik.http.services.{name}.loadbalancer.server.port": port,
    }


def generate_traefik(services: list[dict], domain: str) -> dict:
    """Build a Docker Compose dict with Traefik labels for each HTTP service."""
    compose_services = {}
    for svc in services:
        name = svc["name"]
        labels = traefik_labels(svc, domain)
        compose_services[name] = {
            "extends": {
                "file": f"../{svc.get('path', f'services/{name}.yaml')}",
                "service": name,
            },
            "labels": labels,
            "networks": ["${DEFAULT_NETWORK}"],
        }

    return {
        "version": "3.8",
        "services": compose_services,
        "networks": {
            "${DEFAULT_NETWORK}": {"external": True}
        },
    }


def generate_traefik_dynamic(services: list[dict], domain: str) -> dict:
    """Build Traefik dynamic configuration (routers + services)."""
    routers = {}
    svc_configs = {}
    for svc in services:
        name = svc["name"]
        host = svc.get("reverse_proxy", {}).get("host", f"{name}.{domain}")
        hc = svc.get("healthcheck", {})
        port = "80"
        if hc.get("url"):
            import re
            m = re.search(r":(\d+)", hc["url"])
            if m:
                port = m.group(1)

        routers[name] = {
            "rule": f"Host(`{host}`)",
            "entryPoints": ["websecure"],
            "service": name,
            "tls": {"certResolver": "letsencrypt"},
        }
        svc_configs[name] = {
            "loadBalancer": {
                "servers": [{"url": f"http://{name}:{port}"}]
            }
        }

    return {"http": {"routers": routers, "services": svc_configs}}


# ── caddy ─────────────────────────────────────────────────────────────────────


def generate_caddyfile(services: list[dict], domain: str) -> str:
    """Return a Caddyfile with one block per HTTP service."""
    lines = [
        "# Caddyfile — generated by scripts/reverse-proxy-configurator.py",
        f"# Domain: {domain}",
        f"# Generated: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}",
        "",
    ]
    for svc in services:
        name = svc["name"]
        host = svc.get("reverse_proxy", {}).get("host", f"{name}.{domain}")
        hc = svc.get("healthcheck", {})
        port = "80"
        if hc.get("url"):
            import re
            m = re.search(r":(\d+)", hc["url"])
            if m:
                port = m.group(1)

        lines += [
            f"{host} {{",
            f"    reverse_proxy {name}:{port}",
            f"    # {svc.get('description', name)}",
            "}",
            "",
        ]
    return "\n".join(lines)


def generate_caddy_compose(services: list[dict], caddyfile_path: str) -> dict:
    """Return a minimal Compose file that mounts the generated Caddyfile."""
    return {
        "version": "3.8",
        "services": {
            "caddy": {
                "image": "caddy:latest",
                "container_name": "caddy",
                "restart": "unless-stopped",
                "ports": ["${PORT_CADDY_HTTP:-80}:80", "${PORT_CADDY_HTTPS:-443}:443"],
                "volumes": [
                    f"./{caddyfile_path}:/etc/caddy/Caddyfile:ro",
                    "${DOCKER_DATA}/caddy/data:/data",
                    "${DOCKER_DATA}/caddy/config:/config",
                ],
                "networks": ["${DEFAULT_NETWORK}"],
            }
        },
        "networks": {"${DEFAULT_NETWORK}": {"external": True}},
    }


# ── docs ──────────────────────────────────────────────────────────────────────


def generate_proxy_doc(services: list[dict], backend: str, domain: str) -> str:
    """Return Markdown documentation for the proxy setup."""
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    lines = [
        "# Reverse Proxy Setup",
        "",
        f"> Generated {now} by `scripts/reverse-proxy-configurator.py`  ",
        f"> Backend: **{backend}** | Domain: **{domain}**",
        "",
        "## Services exposed via reverse proxy",
        "",
        "| Service | Host | Description |",
        "|---------|------|-------------|",
    ]
    for svc in services:
        name = svc["name"]
        host = svc.get("reverse_proxy", {}).get("host", f"{name}.{domain}")
        desc = svc.get("description", "")
        lines.append(f"| {name} | `{host}` | {desc} |")

    lines += [
        "",
        "## Quick Start",
        "",
        f"1. Copy `stacks/proxy-{backend}.yaml` to your deployment directory.",
        "2. Ensure your `.env` file has `BASE_DOMAIN` and `DEFAULT_NETWORK` set.",
        "3. Start the proxy stack:",
        "",
        "```bash",
        f"docker compose -f stacks/proxy-{backend}.yaml up -d",
        "```",
        "",
        "## Backend-specific notes",
        "",
    ]

    if backend == "godoxy":
        lines += [
            "### godoxy",
            "Labels are applied via the `proxy.*` label namespace.",
            "Ensure your godoxy instance is running on the same Docker network.",
        ]
    elif backend == "traefik":
        lines += [
            "### Traefik",
            "- Dynamic config is written to `stacks/traefik-dynamic.yaml`.",
            "- Mount it in your Traefik container under `/etc/traefik/dynamic/`.",
            "- `tls.certresolver` defaults to `letsencrypt` — adjust as needed.",
        ]
    elif backend == "caddy":
        lines += [
            "### Caddy",
            "- The generated `Caddyfile` is in `stacks/Caddyfile`.",
            "- Mount it into the Caddy container (done automatically by the compose file).",
        ]

    return "\n".join(lines) + "\n"


# ── main ──────────────────────────────────────────────────────────────────────


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate reverse proxy configuration for HTTP-exposing services.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--backend",
        choices=BACKENDS,
        required=True,
        help="Reverse proxy backend to generate config for.",
    )
    parser.add_argument(
        "--domain",
        default="${BASE_DOMAIN}",
        metavar="DOMAIN",
        help="Base domain (default: uses ${BASE_DOMAIN} variable).",
    )
    parser.add_argument(
        "--output-dir",
        default="stacks",
        metavar="DIR",
        help="Directory to write output files (default: stacks/).",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    domain = args.domain
    backend = args.backend
    output_dir = REPO_ROOT / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)
    DOCS_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Loading HTTP services from registry …")
    services = load_http_services(domain)
    print(f"Found {len(services)} HTTP-exposing service(s).")

    if backend == "godoxy":
        compose = generate_godoxy(services, domain)
        out_yaml = output_dir / "proxy-godoxy.yaml"
        with open(out_yaml, "w") as f:
            yaml.dump(compose, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
        print(f"Written: {out_yaml.relative_to(REPO_ROOT)}")

    elif backend == "traefik":
        compose = generate_traefik(services, domain)
        out_yaml = output_dir / "proxy-traefik.yaml"
        with open(out_yaml, "w") as f:
            yaml.dump(compose, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
        print(f"Written: {out_yaml.relative_to(REPO_ROOT)}")

        # Also write dynamic config
        dynamic = generate_traefik_dynamic(services, domain)
        dyn_path = output_dir / "traefik-dynamic.yaml"
        with open(dyn_path, "w") as f:
            yaml.dump(dynamic, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
        print(f"Written: {dyn_path.relative_to(REPO_ROOT)}")

    elif backend == "caddy":
        caddyfile_rel = "stacks/Caddyfile"
        caddyfile_abs = REPO_ROOT / caddyfile_rel
        caddyfile_content = generate_caddyfile(services, domain)
        with open(caddyfile_abs, "w") as f:
            f.write(caddyfile_content)
        print(f"Written: {caddyfile_abs.relative_to(REPO_ROOT)}")

        compose = generate_caddy_compose(services, "Caddyfile")
        out_yaml = output_dir / "proxy-caddy.yaml"
        with open(out_yaml, "w") as f:
            yaml.dump(compose, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
        print(f"Written: {out_yaml.relative_to(REPO_ROOT)}")

    # Markdown docs
    doc_path = DOCS_DIR / "PROXY-SETUP.md"
    doc_content = generate_proxy_doc(services, backend, domain)
    with open(doc_path, "w") as f:
        f.write(doc_content)
    print(f"Written: {doc_path.relative_to(REPO_ROOT)}")

    print("\nDone.")


if __name__ == "__main__":
    main()
