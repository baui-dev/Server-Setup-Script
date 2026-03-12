Goal:
Create a system that allows a user to run a setup script where they select which services/containers to install. The script should then automatically generate:

A Docker Compose stack YAML file per category

A .env configuration file containing the configurable variables for the selected services

The user must not need to open or modify any YAML files manually. All configuration should happen through the generated .env file.

Follow these steps:

1. Reorganize the Repository Structure

Analyze all existing Docker Compose YAML files and reorganize them into a clear and logical directory structure.

Requirements:

Group services by category.

Create folders and subfolders where appropriate.

Use consistent and descriptive naming conventions.

Detect and remove duplicate services or redundant files.

Ensure every service exists only once in the repository.

Example structure (adapt if needed):

/services
    /monitoring
    /media
    /files
    /network
    /security
    /automation

Each service should have its own folder containing its compose file and metadata.

2. Expand the Service Collection

Search online for additional services that fit the existing categories.

Sources to check:

https://github.com

https://awesome-docker-compose.com/

https://awesome-selfhosted.net/index.html

https://selfh.st/apps/

Requirements:

Only include services that are:

Fully open source

Free to use

Actively maintained

Prefer services with Docker images and documented Docker Compose setups.

Add them to the correct category.

3. Create Central Documentation

Create a central documentation file (e.g., SERVICES.md).

For every service include:

Service name

Category

Short description

Link to GitHub repository

Link to Docker image/repository

Key features

Advantages compared to other services in the same category

Disadvantages or limitations

This document should help users choose between alternatives.

4. Standardize All Compose Files

For every service, locate its official documentation online and update the compose file.

Each compose file must follow this structure:

At the top of the file (uncommented) include:

GitHub repository link

Docker repository link

Short description

Official documentation link

Provide a working minimal default Docker Compose configuration that:

Runs without any additional configuration

Uses sensible default ports and volumes

Matches official documentation examples

After the working default configuration:

Include all additional environment variables and advanced options

These must be commented out

Each option should include an explanation comment

Goal:
Users should not need to open the upstream repository to understand the configuration.

5. Test All Services

Testing must be performed for every service and category.

Individual Service Tests

For each service:

Run:

docker compose up

Verify that the service starts successfully using the default configuration.

If the service fails:

Check the official documentation

Correct the compose file

Retest

Repeat until the service runs successfully.

Category Stack Tests

After individual services work:

Generate a category stack compose file that includes all services in that category.

Deploy the full stack.

Verify that:

All containers start

No conflicts occur (ports, volumes, networks).

If failures occur:

Check documentation

Fix configuration conflicts

Retest until the stack deploys successfully.

Final Goal

The repository should provide:

A setup script allowing users to choose services

Automatically generated:

Category stack compose files

.env configuration files

A clean service structure

Fully tested Docker Compose configurations

Comprehensive documentation

Users should be able to deploy selected services without editing YAML files manually.


1 — Repository target layout (single source of truth)
repo-root
│
├── services/                      # all service definitions, one canonical location
│   ├── ai/
│   ├── communication/
│   ├── development/
│   ├── files/
│   ├── media/
│   │   ├── movies-tv/
│   │   ├── music/
│   │   └── images/
│   ├── networking/
│   │   ├── dns/
│   │   ├── reverse-proxy/
│   │   ├── monitoring/
│   │   └── vpn/
│   ├── productivity/
│   │   ├── notes/
│   │   ├── bookmarks/
│   │   └── tasks/
│   ├── server/
│   │   ├── dashboards/
│   │   ├── management/
│   │   └── auth/
│   └── misc/
│
├── stacks/                         # generated category stacks
│   ├── media-stack.yaml
│   └── networking-stack.yaml
│
├── templates/
│   ├── service-template.yaml       # canonical YAML template (derived from jellyfin.yaml)
│   └── env-template.env
│
├── registry/
│   └── services.json               # service metadata registry (single source)
│
├── scripts/
│   ├── setup.sh                    # interactive selection + .env generator + stack generator
│
├── docs/
│   └── SERVICES.md                 # generated human-facing doc per service
│


2 — Canonical environment variable names (single unified set)

Use these across all templates. No media-specific global vars (except when the service needs them — declare per-service).

# core
TZ
PUID
PGID
DOCKER_DATA        # path to dockerdata root (e.g. /srv/dockerdata)
DOCKER_LOGS
DOCKER_BACKUPS
BASE_DOMAIN        # e.g. example.com
DEFAULT_NETWORK    # default docker network name used by stacks
BASE_PORT          # integer base for auto port assignment (e.g. 30000)

# optional common DB / cache credentials (only added to .env when needed)
POSTGRES_USER
POSTGRES_PASSWORD
POSTGRES_DB
MYSQL_ROOT_PASSWORD
MYSQL_DATABASE
MYSQL_USER
MYSQL_PASSWORD
REDIS_PASSWORD

# service-specific port variables (pattern)
PORT_<SERVICE_UPPER>    # e.g. PORT_JELLYFIN

Notes:

DOCKER_DATA is the single canonical data root; each service mounts into DOCKER_DATA/<category>/<service>/...

BASE_PORT drives auto-allocation (see port resolver below).

3 — Service file placement & naming rules (canonicalization)

Every service must have exactly one canonical YAML file:

services/<category>/<subcategory>/<service-name>.yaml

If duplicates exist, keep only one canonical file, update registry/services.json to point to the kept file.

Filenames and service names use kebab-case (lowercase, hyphens).


4 — Canonical service YAML structure (derived from jellyfin.yaml)

Each service YAML must begin with an explicit metadata header and then a working, minimal compose definition. All optional/advanced settings must be commented and explained.

All services must follow the same format as jellyfin.yaml.

Structure:

# SERVICE NAME
# GitHub: <repo>
# Image: <docker image>
# Docs: <documentation link>
#
# Description of the service
# Short explanation of what it does.

services:
  servicename:
    image:
    container_name:
    hostname:
    restart: unless-stopped

    environment:
      - TZ=${TZ}
      - PUID=${PUID}
      - PGID=${PGID}

      # Optional environment variables commented out
      # - SERVICE_PublishedServerUrl=servicename + ${BASE_DOMAIN}

    volumes:
      - ${BASE_DATA}/service/config:/config
      - ${BASE_DATA}/service/data:/data

      # optional mounts commented out

    ports:
      - ${PORT_SERVICE:-XXXX}:XXXX

    # optional features commented


Rules:

The compose must run with the defaults and only the .env file (no manual YAML edit).

For any bind mounts, use DOCKER_DATA/<category>/<service>/....

For ports, use ${PORT_<SERVICE>:-${AUTO_PORT_<SERVICE>}} — generator sets AUTO_PORT_* at generation time if PORT_* not defined.

All commented options must include a one-line explanation.

5 — Registry schema (services.json) — single authoritative metadata

Create registry/services.json. Each entry must include dependency, reverse-proxy, health-check and compatibility metadata.

Example entry:

{
  "services": [
    {
      "name": "jellyfin",
      "display_name": "Jellyfin",
      "category": "media",
      "subcategory": "movies-tv",
      "path": "services/media/movies-tv/jellyfin/jellyfin.yaml",
      "description": "Open source media server",
      "github": "https://github.com/jellyfin/jellyfin",
      "docker_image": "jellyfin/jellyfin",
      "ports": ["PORT_JELLYFIN"],
      "requires": [],
      "exposes_http": true,
      "reverse_proxy": {
        "preferred": "godoxy",
        "host": "jellyfin.${BASE_DOMAIN}",
        "path": "/"
      },
      "healthcheck": {
        "url": "http://localhost:8096",
        "interval_seconds": 10,
        "timeout_seconds": 5
      },
      "compatibility": {
        "architectures": ["amd64", "arm64"],
        "minimum_docker_version": "20.10"
      }
    }
  ]
}

The registry drives setup UI, stack generator, graph generator, proxy configurator, docs.

6 — Port conflict and auto-allocation rules

BASE_PORT (from .env, e.g. 30000) + service index → AUTO_PORT if no PORT_<SERVICE> provided.

Auto-assignment algorithm:

Read all selected services and requested ports.

Build a set of already reserved ports (explicit PORT_* variables + typical system ports).

For each service missing explicit port, assign BASE_PORT + next_free_index (skip reserved).

Write assigned ports as AUTO_PORT_<SERVICE> into generated .env.

The generator must detect collisions (same port requested for different services) and either:

fail with actionable message, or

auto-resolve by incrementing until free, and log the change to stacks/<category>-stack.yaml comments.

7 — Setup script (scripts/setup.sh)

Behavior (precise):

Read registry/services.json.

Present an interactive menu (text UI) grouped by category/subcategory.

Allow search, multi-select, “select all in category”, and “select recommended stack”.

After selection:

Resolve dependencies (requires) and propose auto-adding required services.

Compute port assignments and write final .env (include both PORT_* and AUTO_PORT_* entries).

Generate per-category stacks under stacks/ by merging service compose blocks.

Generate a top-level stacks/combined-stack.yaml if user requests.

Generate reverse proxy config via scripts/reverse-proxy-configurator.py.

Generate dependency graph via scripts/generate-dependency-graph.py.

Optionally run scripts/test-services.sh for smoke tests (user confirmation).

Output files:

.env (final)

stacks/<category>-stack.yaml (for each affected category)

docs/SERVICES.md (updated)

graphs/dependency-<timestamp>.dot and SVG/PNG

8 — Stack generator (scripts/generate-stacks.py)

Responsibilities:

Load each service YAML (path from registry).

Normalize service names, volumes, networks.

Merge services into one compose file per category:

unify networks: section

define shared volumes: in top-level if used by multiple services

preserve service container_name but prefix when merging to avoid collisions (optionally)

Insert comments listing:

source file path

assigned ports and which .env variable controls them

Detect and resolve:

port collisions (see port resolver)

duplicate volume names (rename to category__service__vol)

Output stacks/<category>-stack.yaml with version: '3.8'.

9 — Reverse proxy automation (scripts/reverse-proxy-configurator.py)

Primary: godoxy (default). Provide CLI flags to output configs also for Traefik or Caddy.

Why godoxy as default:

Lightweight, simple label-based configuration.

Minimal external dependencies.

Good for straightforward host+path routing use-cases.

Matches the repo's intent (small, container-first stacks).

When to prefer Traefik:

You need automatic Let's Encrypt certificate management and dynamic backends across many domains.

You need complex routing rules, middleware chaining, or advanced HTTP features.

Traefik integrates with Docker labels natively and provides metrics and dashboard.

When to prefer Caddy:

You prefer a simpler file-based config but with automatic HTTPS and fewer moving parts than Traefik.

Caddy is strong for static-site and reverse proxy with easy TLS.

Configurator responsibilities:

Read selected services and their reverse_proxy metadata (registry + YAML).

For each service where exposes_http: true:

Generate Godoxy labels and place them as commented examples in each service YAML and add final labels into the merged stack if user chooses to enable proxy integration.

Example Godoxy labels:

labels:
  - "godoxy.hostname=jellyfin.${BASE_DOMAIN}"
  - "godoxy.path=/"
  - "godoxy.tls=true"

If Traefik selected, generate dynamic file provider snippet (YAML) with routers/services/entrypoints and recommended labels:

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.jellyfin.rule=Host(`jellyfin.${BASE_DOMAIN}`)"
  - "traefik.http.services.jellyfin.loadbalancer.server.port=8096"

If Caddy selected, generate a Caddyfile snippet and optionally a Docker service for Caddy.

Write proxy configs to stacks/proxy-<backend>.yaml and to docs/PROXY-SETUP.md.

Security:

Add comments recommending BASE_DOMAIN, HTTPS, and firewall rules.

For services exposing sensitive ports, default exposes_http to false unless docs indicate a web UI.

10 — Dependency graph generation (scripts/generate-dependency-graph.py)

Input: registry/services.json and selected services.

Output: GraphViz DOT file graphs/dependency-<timestamp>.dot and rendered .svg.

Graph details:

nodes: services (label: display_name)

edges: requires relationships (directed)

node colors / shapes indicate:

reverse_proxy endpoint (exposes_http → rectangle)

database/cache services (diamond)

optional services (dashed border)

annotate nodes with assigned ports and healthcheck status (if available).

Use Graphviz dot or Python graphviz/networkx to render PNG/SVG.

Store graphs in graphs/.

This graph is used to:

visualize startup order

detect cycles / missing dependencies

produce a human-readable startup plan in docs/STARTUP_PLAN.md.

11 — Service compatibility matrix

Generate docs/COMPATIBILITY_MATRIX.md and registry/compatibility.csv.

Each service entry includes:

architectures supported (amd64, arm64, etc.)

minimum Docker version

known conflicts (e.g., requires priviledged mode, host networking)

mutual incompatibilities (e.g., service A cannot run with service B on same host because both expect 0.0.0.0:80)

Compatibility matrix can be generated from registry fields:

"compatibility": {
  "architectures": ["amd64", "arm64"],
  "minimum_docker_version": "20.10",
  "requires_privileged": false,
  "conflicts_with": ["some-other-service"]
}

The matrix generator crosschecks selected services and warns of architecture mismatches or conflicts during setup.

12 — Validation script (scripts/validate-services.py)

Checks:

YAML syntax (strict)

presence of required metadata in header

existence of docker_image and github links

exposes_http boolean consistency with reverse_proxy metadata

ports: declared ports valid numeric ranges

compatibility fields present and sensible

duplicate services or path inconsistencies

cycles in requires graph (report and refuse if present unless overridden)

Outputs human-readable report and machine-readable validate-report.json.

13 — Automated testing (scripts/test-services.sh)

Per-service tests (smoke tests):

For each service S:

docker compose -f <service-yaml> up -d

Wait up to configurable timeout (e.g. 60s)

Check container status + logs

If healthcheck present, poll healthcheck URL.

Tear down container after test (unless user asked to keep).

Record test results to tests/results-<timestamp>.json.

For category stacks: bring up whole category, check for:

conflicting ports

service restarts/crashes

unreachable healthchecks

Retry loop:

On failure, consult registry docs link and attempt automatic fixes from known patterns (e.g., missing TZ, or missing PUID/PGID defaults) — log any automated changes and request human review if uncertain.

Important: Tests run inside a sandboxed environment, and user is warned about possible data changes and port usage.

14 — Expansion rules (finding new services)

When searching external sources (GitHub, awesome-selfhosted, awesome-docker-compose, selfh.st):

Only add services that are:

completely open-source

free-to-use

actively maintained (recent commits within last N months — configurable)

dockerized (official or community image with Dockerfile or documented image)

For each candidate:

add a registry entry (including compatibility, healthcheck, reverse_proxy hints)

add a canonical services/.../<service>/<service>.yaml following the template

put a small note in docs/SERVICES.md comparing it to similar services (advantages / disadvantages)

15 — Deduplication & canonicalization rules

If same docker_image appears multiple times under different names, keep the most complete canonical definition and:

create an alias entry in registry/services.json pointing to canonical path

deprecate duplicates (move to archive/ folder)

For identical YAML files (byte-equal or equivalent), only keep one and update refs.

16 — CI / automation recommendations

Add a GitHub Action (optional) that:

runs scripts/validate-services.py on PRs

lints YAML

generates docs/SERVICES.md and graphs/ artifacts for review

Test runner should run smoke tests only in special runners/labels (not by default on PRs).

17 — Output expectations for Copilot Agent

When you run the Copilot Agent with this prompt, it should produce:

services/ reorganized (with duplicates removed)

registry/services.json fully populated and validated

templates/service-template.yaml (from jellyfin.yaml)

scripts/ folder with the scripts above (executable + documented)

stacks/ generated for the selected services

.env created with PORT_* and AUTO_PORT_* values

docs/ updated with SERVICES.md, COMPATIBILITY_MATRIX.md, PROXY-SETUP.md, STARTUP_PLAN.md

graphs/ containing the dependency graph(s)

tests/ output reporting result of smoke tests

18 — Short examples of generated artifacts

Registry snippet

{
  "name": "jellyfin",
  "display_name": "Jellyfin",
  "category": "media",
  "subcategory": "movies-tv",
  "path": "services/media/movies-tv/jellyfin/jellyfin.yaml",
  "description": "Open source media server",
  "github": "https://github.com/jellyfin/jellyfin",
  "docker_image": "jellyfin/jellyfin",
  "ports": ["PORT_JELLYFIN"],
  "requires": [],
  "exposes_http": true,
  "reverse_proxy": { "preferred": "godoxy", "host": "jellyfin.${BASE_DOMAIN}", "path": "/" },
  "healthcheck": { "url": "http://localhost:8096", "interval_seconds": 10 },
  "compatibility": { "architectures": ["amd64","arm64"], "minimum_docker_version":"20.10" }
}

Godoxy labels example (inserted by configurator into merged stack when proxy integration enabled)

labels:
  - "godoxy.hostname=jellyfin.${BASE_DOMAIN}"
  - "godoxy.path=/"
  - "godoxy.tls=true"
  - "godoxy.upstream_port=8096"

Traefik labels example

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.jellyfin.rule=Host(`jellyfin.${BASE_DOMAIN}`)"
  - "traefik.http.routers.jellyfin.entrypoints=websecure"
  - "traefik.http.services.jellyfin.loadbalancer.server.port=8096"