#!/usr/bin/env python3
"""
generate-stacks.py — Merge selected service YAML files into per-category and
combined Docker Compose stack files.

Reads registry/services.json to locate service files, loads each service's
compose YAML, and writes merged output to stacks/<category>-stack.yaml and
stacks/combined-stack.yaml.

Usage:
    python3 scripts/generate-stacks.py --services jellyfin,sonarr,radarr
    python3 scripts/generate-stacks.py --selection-file path/to/selected.txt
    python3 scripts/generate-stacks.py --services all --output-dir stacks/
"""

import argparse
import json
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML is required. Install it with: pip install pyyaml", file=sys.stderr)
    sys.exit(1)


REPO_ROOT = Path(__file__).resolve().parent.parent
REGISTRY_PATH = REPO_ROOT / "registry" / "services.json"
COMPOSE_VERSION = "3.8"


def load_registry() -> dict:
    """Load and return the services registry."""
    if not REGISTRY_PATH.exists():
        print(f"ERROR: Registry not found at {REGISTRY_PATH}", file=sys.stderr)
        sys.exit(1)
    with open(REGISTRY_PATH) as f:
        return json.load(f)


def load_service_yaml(path: Path) -> dict:
    """Load a service YAML file and return parsed content."""
    if not path.exists():
        raise FileNotFoundError(f"Service file not found: {path}")
    with open(path) as f:
        content = f.read()
    return yaml.safe_load(content) or {}


def get_header_comment(service_name: str, source_path: str) -> str:
    """Return a block comment header for a merged service entry."""
    return (
        f"  # ── {service_name} ──────────────────────────────────────────\n"
        f"  # Source: {source_path}\n"
    )


def collect_used_ports(merged_services: dict) -> set:
    """Extract all host port numbers already in use across merged services."""
    used = set()
    for svc in merged_services.values():
        for port_entry in svc.get("ports", []):
            port_str = str(port_entry).split(":")[0]
            # Strip variable references like ${PORT_FOO:-8080} to get default
            m = re.search(r":-(\d+)", port_str)
            if m:
                used.add(int(m.group(1)))
            elif port_str.isdigit():
                used.add(int(port_str))
    return used


def resolve_port_conflicts(new_service: dict, used_ports: set) -> dict:
    """
    Check port bindings in new_service and increment conflicting host ports
    until they are free. Returns the (possibly modified) service dict and
    updates used_ports in place.
    """
    new_ports = []
    for port_entry in new_service.get("ports", []):
        port_str = str(port_entry)
        parts = port_str.split(":")
        if len(parts) >= 2:
            host_part = parts[0]
            container_part = ":".join(parts[1:])
            # Extract numeric default from ${VAR:-PORT} syntax
            m = re.search(r":-(\d+)", host_part)
            if m:
                base_port = int(m.group(1))
                candidate = base_port
                while candidate in used_ports:
                    candidate += 1
                if candidate != base_port:
                    host_part = re.sub(r"(:-)\d+", f"\\g<1>{candidate}", host_part)
                    print(
                        f"    [port conflict] shifted {base_port} → {candidate}",
                        file=sys.stderr,
                    )
                used_ports.add(candidate)
                new_ports.append(f"{host_part}:{container_part}")
            else:
                # Plain numeric host port
                try:
                    base_port = int(host_part)
                    candidate = base_port
                    while candidate in used_ports:
                        candidate += 1
                    used_ports.add(candidate)
                    new_ports.append(f"{candidate}:{container_part}")
                except ValueError:
                    new_ports.append(port_entry)
        else:
            new_ports.append(port_entry)
    if new_ports:
        new_service = dict(new_service)
        new_service["ports"] = new_ports
    return new_service


def merge_services(
    selected: list[dict], registry_map: dict
) -> tuple[dict, dict]:
    """
    Merge selected service definitions.

    Returns:
        by_category: {category: {service_name: service_def}}
        combined:    {service_name: service_def}
    """
    by_category: dict[str, dict] = defaultdict(dict)
    combined: dict = {}
    used_ports: set = set()

    for entry in selected:
        name = entry["name"]
        category = entry["category"]
        rel_path = entry.get("path", "")
        abs_path = REPO_ROOT / rel_path

        print(f"  Loading {name} from {rel_path} …")
        try:
            raw = load_service_yaml(abs_path)
        except (FileNotFoundError, yaml.YAMLError) as exc:
            print(f"    WARNING: {exc}", file=sys.stderr)
            continue

        svc_block = raw.get("services", {})
        if not svc_block:
            print(f"    WARNING: No 'services:' block in {rel_path}", file=sys.stderr)
            continue

        for svc_key, svc_def in svc_block.items():
            # Resolve key conflicts by appending category suffix
            final_key = svc_key
            if final_key in combined:
                final_key = f"{svc_key}_{category}"
                print(
                    f"    [key conflict] renamed '{svc_key}' → '{final_key}'",
                    file=sys.stderr,
                )

            svc_def = resolve_port_conflicts(svc_def, used_ports)
            by_category[category][final_key] = svc_def
            combined[final_key] = svc_def

    return by_category, combined


def write_stack(
    services: dict,
    output_path: Path,
    title: str,
    source_note: str = "",
) -> None:
    """Write a Docker Compose file for the given services dict."""
    output_path.parent.mkdir(parents=True, exist_ok=True)

    header_lines = [
        f"# {title}",
        f"# Generated by scripts/generate-stacks.py",
    ]
    if source_note:
        header_lines.append(f"# {source_note}")
    header_lines.append("#")
    header_lines.append("# Edit port variables in your .env file before deploying.")
    header_lines.append("")

    compose_doc = {
        "version": COMPOSE_VERSION,
        "services": services,
    }

    header = "\n".join(header_lines)
    body = yaml.dump(compose_doc, default_flow_style=False, sort_keys=False, allow_unicode=True)

    with open(output_path, "w") as f:
        f.write(header)
        f.write(body)

    print(f"  → Written: {output_path.relative_to(REPO_ROOT)}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Merge service YAML files into Docker Compose stacks.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--services",
        metavar="NAME[,NAME…]",
        help="Comma-separated list of service names, or 'all'.",
    )
    group.add_argument(
        "--selection-file",
        metavar="FILE",
        help="Path to a file with one service name per line.",
    )
    parser.add_argument(
        "--output-dir",
        metavar="DIR",
        default="stacks",
        help="Directory to write stack files (default: stacks/).",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    output_dir = REPO_ROOT / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    print("Loading registry …")
    registry = load_registry()
    all_services = registry.get("services", [])
    registry_map = {s["name"]: s for s in all_services}

    # Resolve requested service names
    if args.services:
        if args.services.strip().lower() == "all":
            requested = list(registry_map.keys())
        else:
            requested = [n.strip() for n in args.services.split(",") if n.strip()]
    else:
        sel_file = Path(args.selection_file)
        if not sel_file.exists():
            print(f"ERROR: Selection file not found: {sel_file}", file=sys.stderr)
            sys.exit(1)
        requested = [
            line.strip()
            for line in sel_file.read_text().splitlines()
            if line.strip() and not line.startswith("#")
        ]

    unknown = [n for n in requested if n not in registry_map]
    if unknown:
        print(f"WARNING: Unknown service(s) ignored: {', '.join(unknown)}", file=sys.stderr)

    selected = [registry_map[n] for n in requested if n in registry_map]
    if not selected:
        print("ERROR: No valid services selected.", file=sys.stderr)
        sys.exit(1)

    print(f"Merging {len(selected)} service(s) …")
    by_category, combined = merge_services(selected, registry_map)

    # Per-category stacks
    print("\nWriting category stacks …")
    for category, services in by_category.items():
        out = output_dir / f"{category}-stack.yaml"
        write_stack(
            services,
            out,
            title=f"{category.upper()} STACK",
            source_note=f"Services: {', '.join(services.keys())}",
        )

    # Combined stack
    print("\nWriting combined stack …")
    write_stack(
        combined,
        output_dir / "combined-stack.yaml",
        title="COMBINED STACK",
        source_note=f"Categories: {', '.join(sorted(by_category.keys()))}",
    )

    print(f"\nDone. {len(combined)} service(s) written to {output_dir.relative_to(REPO_ROOT)}/")


if __name__ == "__main__":
    main()
