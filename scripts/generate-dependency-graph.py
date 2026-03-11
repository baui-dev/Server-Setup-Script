#!/usr/bin/env python3
"""
generate-dependency-graph.py — Visualise service dependencies as a GraphViz
DOT file and produce a human-readable startup plan.

Node shapes:
  rectangle  — HTTP-exposing services
  diamond    — database / cache services (names containing db, postgres,
               mysql, mariadb, redis, mongo, elastic, influx)
  ellipse    — all other services

Edges represent `requires` relationships listed in the registry.

Output files:
  graphs/dependency-<timestamp>.dot   GraphViz DOT source
  docs/STARTUP_PLAN.md               Ordered startup guide

Usage:
    python3 scripts/generate-dependency-graph.py
    python3 scripts/generate-dependency-graph.py --output-dir graphs/
    python3 scripts/generate-dependency-graph.py --services jellyfin,sonarr
"""

import argparse
import json
import sys
from collections import defaultdict, deque
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
REGISTRY_PATH = REPO_ROOT / "registry" / "services.json"
GRAPHS_DIR = REPO_ROOT / "graphs"
DOCS_DIR = REPO_ROOT / "docs"

# Service name fragments that identify database/cache services
DB_KEYWORDS = {
    "postgres", "mysql", "mariadb", "redis", "mongo", "elastic",
    "influx", "db", "database", "cache", "memcache",
}


# ── helpers ──────────────────────────────────────────────────────────────────


def load_registry() -> list[dict]:
    if not REGISTRY_PATH.exists():
        print(f"ERROR: Registry not found at {REGISTRY_PATH}", file=sys.stderr)
        sys.exit(1)
    with open(REGISTRY_PATH) as f:
        return json.load(f).get("services", [])


def node_shape(svc: dict) -> str:
    name = svc["name"].lower()
    if any(kw in name for kw in DB_KEYWORDS):
        return "diamond"
    if svc.get("exposes_http"):
        return "rectangle"
    return "ellipse"


def node_color(svc: dict) -> str:
    shape = node_shape(svc)
    return {
        "diamond": "#FFD700",
        "rectangle": "#87CEEB",
        "ellipse": "#90EE90",
    }.get(shape, "#FFFFFF")


def sanitize_id(name: str) -> str:
    """Return a DOT-safe identifier."""
    return name.replace("-", "_").replace(".", "_")


# ── DOT generation ────────────────────────────────────────────────────────────


def build_dot(services: list[dict]) -> str:
    """Return a GraphViz DOT string for the dependency graph."""
    lines = [
        "digraph service_dependencies {",
        '    graph [rankdir=LR, fontname="Helvetica", label="Service Dependency Graph", '
        'labelloc=t, fontsize=16];',
        '    node [fontname="Helvetica", fontsize=11, style=filled];',
        '    edge [fontname="Helvetica", fontsize=10];',
        "",
    ]

    # Group by category for subgraphs
    by_cat: dict[str, list[dict]] = defaultdict(list)
    for svc in services:
        by_cat[svc.get("category", "misc")].append(svc)

    for cat, members in sorted(by_cat.items()):
        lines.append(f"    subgraph cluster_{sanitize_id(cat)} {{")
        lines.append(f'        label="{cat.upper()}";')
        lines.append('        style=dashed;')
        for svc in members:
            sid = sanitize_id(svc["name"])
            shape = node_shape(svc)
            color = node_color(svc)
            label = svc.get("display_name", svc["name"])
            desc = svc.get("description", "")
            tooltip = desc.replace('"', '\\"')
            lines.append(
                f'        {sid} [label="{label}", shape={shape}, '
                f'fillcolor="{color}", tooltip="{tooltip}"];'
            )
        lines.append("    }")
        lines.append("")

    # Edges
    for svc in services:
        sid = sanitize_id(svc["name"])
        for req in svc.get("requires", []):
            rid = sanitize_id(req)
            lines.append(f"    {rid} -> {sid};")

    lines.append("}")
    return "\n".join(lines)


# ── Topological sort for startup plan ────────────────────────────────────────


def topological_sort(services: list[dict]) -> list[list[str]]:
    """
    Return services grouped in startup waves (topological levels).
    Wave 0 = services with no dependencies.
    """
    name_set = {s["name"] for s in services}
    in_degree: dict[str, int] = {s["name"]: 0 for s in services}
    dependents: dict[str, list[str]] = defaultdict(list)

    for svc in services:
        for req in svc.get("requires", []):
            if req in name_set:
                in_degree[svc["name"]] += 1
                dependents[req].append(svc["name"])

    queue = deque(name for name, deg in in_degree.items() if deg == 0)
    waves: list[list[str]] = []

    while queue:
        wave = list(queue)
        waves.append(sorted(wave))
        queue.clear()
        for name in wave:
            for dep in dependents[name]:
                in_degree[dep] -= 1
                if in_degree[dep] == 0:
                    queue.append(dep)

    # Handle cycles (remaining nodes)
    remaining = [n for n, d in in_degree.items() if d > 0]
    if remaining:
        waves.append(sorted(remaining))

    return waves


# ── Markdown startup plan ─────────────────────────────────────────────────────


def build_startup_plan(services: list[dict], waves: list[list[str]]) -> str:
    svc_map = {s["name"]: s for s in services}
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    lines = [
        "# Service Startup Plan",
        "",
        f"> Generated {now} by `scripts/generate-dependency-graph.py`",
        "",
        "Start services in the order shown below. Each wave can be started in parallel.",
        "",
    ]
    for i, wave in enumerate(waves):
        lines.append(f"## Wave {i + 1}")
        lines.append("")
        lines.append("| Service | Category | Description | Requires |")
        lines.append("|---------|----------|-------------|---------|")
        for name in wave:
            svc = svc_map.get(name, {})
            cat = svc.get("category", "")
            desc = svc.get("description", "")
            reqs = ", ".join(svc.get("requires", [])) or "—"
            lines.append(f"| {name} | {cat} | {desc} | {reqs} |")
        lines.append("")

    lines += [
        "## Legend",
        "",
        "| Shape | Meaning |",
        "|-------|---------|",
        "| Rectangle | HTTP-exposing service |",
        "| Diamond   | Database / cache |",
        "| Ellipse   | Other / background service |",
        "",
    ]
    return "\n".join(lines)


# ── entry point ───────────────────────────────────────────────────────────────


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a GraphViz dependency graph and startup plan.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--output-dir",
        default="graphs",
        metavar="DIR",
        help="Directory to write DOT file (default: graphs/).",
    )
    parser.add_argument(
        "--services",
        metavar="NAME[,NAME…]",
        default=None,
        help="Comma-separated subset of service names to include (default: all).",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    output_dir = REPO_ROOT / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)
    DOCS_DIR.mkdir(parents=True, exist_ok=True)

    print("Loading registry …")
    all_services = load_registry()
    svc_map = {s["name"]: s for s in all_services}

    if args.services:
        requested = [n.strip() for n in args.services.split(",") if n.strip()]
        unknown = [n for n in requested if n not in svc_map]
        if unknown:
            print(f"WARNING: Unknown service(s): {', '.join(unknown)}", file=sys.stderr)
        services = [svc_map[n] for n in requested if n in svc_map]
    else:
        services = all_services

    if not services:
        print("ERROR: No services to graph.", file=sys.stderr)
        sys.exit(1)

    print(f"Building graph for {len(services)} service(s) …")

    # DOT file
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    dot_path = output_dir / f"dependency-{timestamp}.dot"
    dot_content = build_dot(services)
    dot_path.write_text(dot_content)
    print(f"Written: {dot_path.relative_to(REPO_ROOT)}")
    print(
        f"  Render with: dot -Tsvg {dot_path.relative_to(REPO_ROOT)} "
        f"-o graphs/dependency-{timestamp}.svg"
    )

    # Startup plan
    waves = topological_sort(services)
    plan = build_startup_plan(services, waves)
    plan_path = DOCS_DIR / "STARTUP_PLAN.md"
    plan_path.write_text(plan)
    print(f"Written: {plan_path.relative_to(REPO_ROOT)}")

    print(f"\nStartup waves: {len(waves)}")
    for i, wave in enumerate(waves):
        print(f"  Wave {i + 1}: {', '.join(wave)}")


if __name__ == "__main__":
    main()
