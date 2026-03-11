# Service Catalog

This document describes all available services in the Server Setup Script.
Use `scripts/setup.sh` to interactively select and deploy services.

## Quick Start

```bash
bash scripts/setup.sh
```

## Categories

- [AI](#ai)
- [Communication](#communication)
- [Development](#development)
- [Files](#files)
- [Media - Movies & TV](#media---movies--tv)
- [Media - Music](#media---music)
- [Media - Images](#media---images)
- [Networking - DNS](#networking---dns)
- [Networking - Monitoring](#networking---monitoring)
- [Networking - Reverse Proxy](#networking---reverse-proxy)
- [Networking - VPN](#networking---vpn)
- [Productivity - Bookmarks](#productivity---bookmarks)
- [Productivity - Notes](#productivity---notes)
- [Productivity - Tasks](#productivity---tasks)
- [Server - Auth](#server---auth)
- [Server - Dashboards](#server---dashboards)
- [Server - Management](#server---management)
- [Miscellaneous](#miscellaneous)

---

## AI

### Open WebUI

Web UI for interacting with local LLMs via Ollama or any OpenAI-compatible API.

- **Category**: AI
- **GitHub**: https://github.com/open-webui/open-webui
- **Docker Image**: `ghcr.io/open-webui/open-webui`
- **Default Port**: 3000
- **Key Features**:
  - Supports Ollama and OpenAI-compatible backends
  - Multi-user support with role-based access
  - Conversation history and model switching
  - Image generation support (DALL-E / Stable Diffusion)
  - Plugin/tool-call support
- **Advantages**:
  - Fully self-hosted, no data leaves your server
  - Clean, modern interface comparable to ChatGPT
  - Actively developed with frequent updates
- **Disadvantages/Limitations**:
  - Requires a separate Ollama instance for local models
  - GPU hardware greatly improves performance but is optional

**Deploy**:
```
openwebui
```

---

### n8n

Self-hosted workflow automation platform, similar to Zapier or Make.

- **Category**: AI
- **GitHub**: https://github.com/n8n-io/n8n
- **Docker Image**: `n8nio/n8n`
- **Default Port**: 5678
- **Key Features**:
  - Visual node-based workflow editor
  - 400+ built-in integrations
  - AI/LLM nodes for building AI agents
  - Webhook triggers and scheduling
  - Self-hostable with full data ownership
- **Advantages**:
  - Source-available (fair-code license)
  - AI agent workflows out of the box
  - Large community and template library
- **Disadvantages/Limitations**:
  - Fair-code license restricts commercial use without a license
  - Complex workflows can be hard to debug

**Deploy**:
```
n8n
```

---

### AnythingLLM

Private LLM workspace with RAG (retrieval-augmented generation) and file upload support.

- **Category**: AI
- **GitHub**: https://github.com/Mintplex-Labs/anything-llm
- **Docker Image**: `mintplexlabs/anythingllm`
- **Default Port**: 3020
- **Key Features**:
  - RAG over uploaded documents (PDF, DOCX, TXT, etc.)
  - Multi-workspace isolation
  - Supports Ollama, OpenAI, Anthropic, and more
  - Agent capabilities with web browsing
  - Multi-user with permissions
- **Advantages**:
  - All-in-one: vector DB, LLM interface, and document ingestion
  - No external dependencies needed
  - Simple setup compared to building a custom RAG stack
- **Disadvantages/Limitations**:
  - Heavier resource usage than simpler chat UIs
  - Less frequent updates than Open WebUI

**Deploy**:
```
anythingllm
```

---

## Communication

### Matrix Synapse

Federated, end-to-end encrypted chat homeserver implementing the Matrix protocol.

- **Category**: Communication
- **GitHub**: https://github.com/element-hq/synapse
- **Docker Image**: `matrixdotorg/synapse`
- **Default Port**: 8008
- **Key Features**:
  - Federated — connects with other Matrix homeservers
  - End-to-end encryption via the Signal protocol
  - Bridges to Slack, Discord, Telegram, WhatsApp, and more
  - Full message history retention on your server
  - Works with Element, FluffyChat, and other clients
- **Advantages**:
  - Truly open, decentralized communication
  - No vendor lock-in; you own your data
  - Rich bridge ecosystem
- **Disadvantages/Limitations**:
  - High resource usage compared to simpler chat servers
  - Complex setup, especially for federation
  - Bridges can be unstable

**Deploy**:
```
matrix-synapse
```

---

### ntfy

Simple HTTP-based push notification server. Subscribe to topics and receive notifications anywhere.

- **Category**: Communication
- **GitHub**: https://github.com/binwiederhier/ntfy
- **Docker Image**: `binwiederhier/ntfy`
- **Default Port**: 8840
- **Key Features**:
  - Send notifications via plain HTTP PUT/POST
  - No account required for public topics
  - Android/iOS apps and web UI
  - Supports attachments, priority levels, and actions
  - Access control lists for private topics
- **Advantages**:
  - Extremely simple API — works with `curl`
  - Lighter than Gotify; no per-app token management
  - Good mobile apps
- **Disadvantages/Limitations**:
  - Topic-based model less suited for per-app notification routing
  - No built-in message history by default (requires config)

**Deploy**:
```
ntfy
```

---

### Gotify

Self-hosted notification server with per-application tokens and a clean web UI.

- **Category**: Communication
- **GitHub**: https://github.com/gotify/server
- **Docker Image**: `gotify/server`
- **Default Port**: 8850
- **Key Features**:
  - Per-application API tokens
  - Real-time WebSocket push
  - Android app and web UI
  - REST API for sending messages
  - Message priority levels
- **Advantages**:
  - Simple to set up and use
  - Per-app token isolation is good for automation
  - Lightweight single-binary server
- **Disadvantages/Limitations**:
  - No iOS app (community workarounds exist)
  - Less active development compared to ntfy
  - No built-in access control beyond tokens

**Deploy**:
```
gotify
```

---

## Development

### Gitea

Lightweight, self-hosted Git service with a GitHub-like web interface.

- **Category**: Development
- **GitHub**: https://github.com/go-gitea/gitea
- **Docker Image**: `gitea/gitea`
- **Default Port**: 3000
- **Key Features**:
  - Repository hosting with issues, PRs, and wikis
  - CI/CD via Gitea Actions (GitHub Actions compatible)
  - Container registry built-in
  - OAuth2 / LDAP / SSO support
  - Organization and team management
- **Advantages**:
  - Very low resource usage (single Go binary)
  - Fast and responsive even on low-end hardware
  - MIT licensed and actively maintained
- **Disadvantages/Limitations**:
  - Smaller ecosystem than GitLab
  - Some advanced CI/CD features lag behind GitLab

**Deploy**:
```
gitea
```

---

### code-server

Visual Studio Code running in the browser, accessible from any device.

- **Category**: Development
- **GitHub**: https://github.com/coder/code-server
- **Docker Image**: `linuxserver/code-server`
- **Default Port**: 8443
- **Key Features**:
  - Full VS Code experience in a browser tab
  - Install extensions from Open VSX or marketplace
  - Integrated terminal on the server
  - File editing directly on server filesystem
  - Password or token authentication
- **Advantages**:
  - Code on any device, including tablets
  - No local IDE installation required
  - Server-side extensions run where your code lives
- **Disadvantages/Limitations**:
  - Some proprietary VS Code extensions are not available
  - Performance depends on server and network latency
  - Single-user by default

**Deploy**:
```
code-server
```

---

### Semaphore

Web UI for running Ansible playbooks and Terraform plans.

- **Category**: Development
- **GitHub**: https://github.com/semaphoreui/semaphore
- **Docker Image**: `semaphoreui/semaphore`
- **Default Port**: 3000
- **Key Features**:
  - Visual task runner for Ansible, Terraform, Bash, and Python
  - Inventory and environment management
  - Scheduled and manual task execution
  - Multi-user with role-based access
  - Task history and logs
- **Advantages**:
  - Much easier than running Ansible from the command line
  - Open source alternative to AWX/Ansible Tower
  - Lightweight and easy to set up
- **Disadvantages/Limitations**:
  - Fewer features than AWX for large-scale deployments
  - Limited alerting/notification options

**Deploy**:
```
semaphore
```

---

## Files

### Nextcloud

Full-featured self-hosted file sharing and collaboration platform.

- **Category**: Files
- **GitHub**: https://github.com/nextcloud/server
- **Docker Image**: `nextcloud`
- **Default Port**: 8880
- **Key Features**:
  - File sync across desktop and mobile clients
  - Collaborative office editing (Collabora / OnlyOffice)
  - Calendar, contacts, and email apps
  - App store with 200+ extensions
  - End-to-end encryption support
- **Advantages**:
  - All-in-one productivity platform
  - Strong mobile and desktop client ecosystem
  - GDPR-compliant, data stays on your server
- **Disadvantages/Limitations**:
  - Heavy resource usage
  - Complex setup for full feature set (requires a database, Redis)
  - Can feel slow compared to commercial alternatives

**Deploy**:
```
nextcloud
```

---

### Filebrowser

Minimal, lightweight web-based file manager for browsing and managing server files.

- **Category**: Files
- **GitHub**: https://github.com/filebrowser/filebrowser
- **Docker Image**: `filebrowser/filebrowser`
- **Default Port**: 8888
- **Key Features**:
  - File upload, download, delete, rename, and preview
  - User management with per-folder permissions
  - Shareable download links
  - Simple search
  - Text file editor
- **Advantages**:
  - Extremely lightweight single binary
  - Zero external dependencies
  - Very easy to configure
- **Disadvantages/Limitations**:
  - No sync clients (upload/download only)
  - No collaboration features
  - Not a replacement for Nextcloud for complex workflows

**Deploy**:
```
filebrowser
```

---

### MinIO

High-performance S3-compatible object storage for self-hosted environments.

- **Category**: Files
- **GitHub**: https://github.com/minio/minio
- **Docker Image**: `minio/minio`
- **Default Ports**: 9000 (API), 9001 (console)
- **Key Features**:
  - Fully S3-compatible API
  - Web console for bucket and object management
  - Versioning, lifecycle policies, and replication
  - Encryption at rest and in transit
  - Suitable for storing ML datasets, backups, and media
- **Advantages**:
  - Works with any S3-compatible tool or library
  - Excellent performance on local storage
  - Scales from single node to distributed clusters
- **Disadvantages/Limitations**:
  - AGPLv3 license; commercial use may require a paid license
  - Overkill for simple file sharing use cases

**Deploy**:
```
minio
```

---

## Media - Movies & TV

### Jellyfin

Open source media server for streaming movies, TV shows, music, and photos.

- **Category**: Media / Movies & TV
- **GitHub**: https://github.com/jellyfin/jellyfin
- **Docker Image**: `jellyfin/jellyfin`
- **Default Port**: 8096
- **Key Features**:
  - Hardware-accelerated transcoding (Intel QSV, NVENC, VAAPI)
  - Live TV and DVR support
  - DLNA and Chromecast support
  - Multi-user with parental controls
  - No mandatory account or subscription
- **Advantages**:
  - Completely free and open source — no premium tier
  - No external account required
  - Active community and frequent releases
- **Disadvantages/Limitations**:
  - Mobile apps less polished than Plex
  - Fewer third-party plugins than Plex
  - Some advanced features require manual configuration

**Deploy**:
```
jellyfin
```

---

### Sonarr

Automated TV series download manager. Monitors RSS feeds and grabs new episodes automatically.

- **Category**: Media / Movies & TV
- **GitHub**: https://github.com/Sonarr/Sonarr
- **Docker Image**: `linuxserver/sonarr`
- **Default Port**: 8989
- **Key Features**:
  - Automated episode downloading with quality profiles
  - Integration with qBittorrent, SABnzbd, and other clients
  - Series calendar and episode tracking
  - Rename and organize downloaded files
  - Notification support (Discord, Slack, email, etc.)
- **Advantages**:
  - Best-in-class TV automation
  - Works seamlessly with the *arr ecosystem
  - Highly configurable quality management
- **Disadvantages/Limitations**:
  - Requires indexers (via Prowlarr) and a download client
  - Learning curve for initial setup
  - No built-in media playback

**Deploy**:
```
sonarr
```

---

### Radarr

Automated movie download manager, forked from Sonarr and adapted for films.

- **Category**: Media / Movies & TV
- **GitHub**: https://github.com/Radarr/Radarr
- **Docker Image**: `linuxserver/radarr`
- **Default Port**: 7878
- **Key Features**:
  - Automated movie downloading with quality profiles
  - Custom format scoring for release selection
  - Integration with download clients and indexers
  - Rename and organize movie files
  - Collection and list management
- **Advantages**:
  - Best-in-class movie automation
  - Consistent UI and config style with Sonarr
  - Large community and active development
- **Disadvantages/Limitations**:
  - Requires indexers and a download client
  - No built-in media server

**Deploy**:
```
radarr
```

---

### Bazarr

Automated subtitle downloader that integrates with Sonarr and Radarr.

- **Category**: Media / Movies & TV
- **GitHub**: https://github.com/morpheus65535/bazarr
- **Docker Image**: `linuxserver/bazarr`
- **Default Port**: 6767
- **Key Features**:
  - Automatic subtitle download for movies and series
  - Supports 50+ subtitle providers (OpenSubtitles, Subscene, etc.)
  - Upgrades subtitles automatically when better versions appear
  - Subtitle scoring and language preferences
  - Integrates directly with Sonarr and Radarr libraries
- **Advantages**:
  - Hands-off subtitle management
  - Supports a huge number of providers
  - Works with any language
- **Disadvantages/Limitations**:
  - Dependent on Sonarr/Radarr being configured first
  - Some providers require paid accounts for high volume
  - Subtitle quality varies by provider

**Deploy**:
```
bazarr
```

---

### Jellyseerr

Media request management portal for Jellyfin users, forked from Overseerr.

- **Category**: Media / Movies & TV
- **GitHub**: https://github.com/Fallenbagel/jellyseerr
- **Docker Image**: `fallenbagel/jellyseerr`
- **Default Port**: 5055
- **Key Features**:
  - Users request movies/TV shows via a friendly UI
  - Integrates with Sonarr, Radarr, and Jellyfin
  - Approval workflows for requests
  - Notifications for request status changes
  - User authentication via Jellyfin accounts
- **Advantages**:
  - Keeps end-users out of the *arr admin UIs
  - Jellyfin-native authentication
  - Beautiful, consumer-friendly interface
- **Disadvantages/Limitations**:
  - Requires Sonarr and Radarr to be configured
  - Less mature than Overseerr (which targets Plex)

**Deploy**:
```
jellyseerr
```

---

### Prowlarr

Centralized indexer manager for the *arr ecosystem.

- **Category**: Media / Movies & TV
- **GitHub**: https://github.com/Prowlarr/Prowlarr
- **Docker Image**: `linuxserver/prowlarr`
- **Default Port**: 9696
- **Key Features**:
  - Manages Usenet and torrent indexers in one place
  - Syncs indexers to Sonarr, Radarr, Lidarr automatically
  - Supports 500+ indexers
  - Search and test indexers from the UI
  - Built-in indexer stats and history
- **Advantages**:
  - Configure indexers once, use everywhere
  - Eliminates per-app indexer configuration
  - Active development, new indexers added regularly
- **Disadvantages/Limitations**:
  - Adds another service to maintain
  - Some niche indexers may not be supported

**Deploy**:
```
prowlarr
```

---

### Maintainerr

Rule-based media library cleanup tool that removes stale content from Jellyfin/Plex via Sonarr/Radarr.

- **Category**: Media / Movies & TV
- **GitHub**: https://github.com/jorenn92/Maintainerr
- **Docker Image**: `jorenn92/maintainerr`
- **Default Port**: 6246
- **Key Features**:
  - Define rules to identify unwatched or old media
  - Dry-run mode to preview deletions
  - Integrates with Sonarr, Radarr, and media servers
  - Scheduled automatic cleanup
  - Dashboard showing media matching rules
- **Advantages**:
  - Keeps your library manageable without manual curation
  - Safe dry-run preview before any deletion
  - Highly configurable rule engine
- **Disadvantages/Limitations**:
  - Requires the full *arr stack to be set up
  - Misconfigured rules can delete desired media

**Deploy**:
```
maintainerr
```

---

## Media - Music

### Lidarr

Automated music download manager, part of the *arr ecosystem.

- **Category**: Media / Music
- **GitHub**: https://github.com/Lidarr/Lidarr
- **Docker Image**: `linuxserver/lidarr`
- **Default Port**: 8686
- **Key Features**:
  - Automated album and artist monitoring
  - Quality profiles for audio formats (FLAC, MP3, etc.)
  - MusicBrainz metadata integration
  - Integration with download clients and Prowlarr
  - Rename and organize music files
- **Advantages**:
  - Consistent *arr-style UI and configuration
  - Excellent metadata sourcing from MusicBrainz
  - Works well with Beets and other music tools
- **Disadvantages/Limitations**:
  - Music indexers are harder to find than video indexers
  - Slower development pace than Sonarr/Radarr
  - Some edge cases with compilation albums

**Deploy**:
```
lidarr
```

---

### slskd

Web-based Soulseek client for peer-to-peer music sharing.

- **Category**: Media / Music
- **GitHub**: https://github.com/slskd/slskd
- **Docker Image**: `slskd/slskd`
- **Default Port**: 5030
- **Key Features**:
  - Soulseek P2P network access via web UI
  - Search, browse, and download music from peers
  - Upload sharing with configurable directories
  - Transfer queue management
  - API for automation
- **Advantages**:
  - Access to a vast catalog of rare and lossless music
  - Modern web interface for the Soulseek network
  - Works server-side, no desktop client needed
- **Disadvantages/Limitations**:
  - Depends on peer availability; not guaranteed downloads
  - Soulseek network has informal etiquette around sharing ratios
  - Not a replacement for indexer-based automation

**Deploy**:
```
slskd
```

---

## Media - Images

### Piwigo

Self-hosted photo gallery and management application.

- **Category**: Media / Images
- **GitHub**: https://github.com/Piwigo/Piwigo
- **Docker Image**: `linuxserver/piwigo`
- **Default Port**: 8101
- **Key Features**:
  - Album organization and photo tagging
  - User and group access control
  - Plugin ecosystem for extended functionality
  - Mobile-friendly web UI
  - Bulk import from server directories
- **Advantages**:
  - Mature, stable project with a long history
  - Rich plugin ecosystem
  - Good for sharing photo collections with others
- **Disadvantages/Limitations**:
  - Older UI compared to newer alternatives like Immich
  - PHP-based stack can be more complex to maintain
  - Less focus on AI features (face recognition, etc.)

**Deploy**:
```
piwigo
```

---

## Networking - DNS

### AdGuard Home

Network-wide DNS-based ad and tracker blocker with a polished web UI.

- **Category**: Networking / DNS
- **GitHub**: https://github.com/AdguardTeam/AdGuardHome
- **Docker Image**: `adguard/adguardhome`
- **Default Port**: 3000 (admin UI)
- **Key Features**:
  - DNS-over-HTTPS (DoH) and DNS-over-TLS (DoT) built-in
  - Blocklist management and custom filtering rules
  - Per-client filtering rules
  - Query log and statistics dashboard
  - Parental control and safe search enforcement
- **Advantages**:
  - Modern, polished UI
  - DoH/DoT support without extra configuration
  - Active development by AdGuard team
- **Disadvantages/Limitations**:
  - Cannot run alongside Pi-hole (DNS port conflict)
  - Smaller community than Pi-hole
  - Fewer third-party integrations

**Deploy**:
```
adguard
```

> ⚠️ **Conflicts with**: `pihole` — both require exclusive access to port 53.

---

### Pi-hole

The original network-wide DNS ad blocker with the largest community.

- **Category**: Networking / DNS
- **GitHub**: https://github.com/pi-hole/pi-hole
- **Docker Image**: `pihole/pihole`
- **Default Port**: 8080 (admin UI)
- **Key Features**:
  - Network-wide ad blocking via DNS
  - Huge library of community blocklists
  - Per-client and per-group filtering (Pi-hole v6)
  - Query log and long-term statistics
  - DHCP server capability
- **Advantages**:
  - Largest community and most documentation
  - Enormous blocklist ecosystem
  - Well-tested and extremely stable
- **Disadvantages/Limitations**:
  - Cannot run alongside AdGuard Home (DNS port conflict)
  - DoH/DoT requires a separate Unbound or cloudflared setup
  - UI less modern than AdGuard Home

**Deploy**:
```
pihole
```

> ⚠️ **Conflicts with**: `adguard` — both require exclusive access to port 53.

---

### Unbound

Validating, recursive DNS resolver typically used behind Pi-hole or AdGuard Home.

- **Category**: Networking / DNS
- **GitHub**: https://github.com/NLnetLabs/unbound
- **Docker Image**: `mvance/unbound`
- **Default Port**: 5335 (internal)
- **Key Features**:
  - Full recursive DNS resolution (no upstream needed)
  - DNSSEC validation
  - Response Rate Limiting (RRL)
  - Configurable caching
  - Works as a local root resolver
- **Advantages**:
  - Eliminates reliance on third-party DNS providers
  - Improved privacy — queries resolve from root servers
  - Pairs perfectly with Pi-hole or AdGuard Home
- **Disadvantages/Limitations**:
  - No web UI (config file only)
  - Slightly slower first-query response until cache warms up
  - Configuration requires understanding of DNS

**Deploy**:
```
unbound
```

---

## Networking - Monitoring

### Beszel

Lightweight, agent-based server monitoring with a minimal web interface.

- **Category**: Networking / Monitoring
- **GitHub**: https://github.com/henrygd/beszel
- **Docker Image**: `henrygd/beszel`
- **Default Port**: 8090
- **Key Features**:
  - CPU, RAM, disk, and network monitoring
  - Agent-based — install on each server to monitor
  - Lightweight single binary (hub and agent)
  - Alert notifications via email, ntfy, Gotify, etc.
  - Historical charts for all metrics
- **Advantages**:
  - Extremely low resource usage
  - Simple setup with minimal configuration
  - Good for monitoring multiple servers from one hub
- **Disadvantages/Limitations**:
  - Fewer metrics and dashboards than Grafana/Prometheus
  - No application-level monitoring
  - Limited customization

**Deploy**:
```
beszel
```

---

### Uptime Kuma

Self-hosted status page and uptime monitor with rich notification support.

- **Category**: Networking / Monitoring
- **GitHub**: https://github.com/louislam/uptime-kuma
- **Docker Image**: `louislam/uptime-kuma`
- **Default Port**: 3001
- **Key Features**:
  - HTTP, TCP, DNS, ping, and Docker container monitoring
  - Beautiful public status page
  - 90+ notification providers (Discord, Slack, Telegram, etc.)
  - Incident history and uptime percentages
  - Certificate expiry monitoring
- **Advantages**:
  - Stunning UI out of the box
  - Massive notification provider support
  - Very easy to add new monitors
- **Disadvantages/Limitations**:
  - Single-user by default (multi-user in newer versions)
  - Not suitable for full infrastructure observability (use Grafana for that)
  - SQLite backend can struggle at very high monitor counts

**Deploy**:
```
uptime-kuma
```

---

## Networking - Reverse Proxy

### Nginx Proxy Manager

GUI-driven reverse proxy built on nginx, ideal for beginners.

- **Category**: Networking / Reverse Proxy
- **GitHub**: https://github.com/NginxProxyManager/nginx-proxy-manager
- **Docker Image**: `jc21/nginx-proxy-manager`
- **Default Port**: 81 (admin UI)
- **Key Features**:
  - Point-and-click proxy host configuration
  - Automatic Let's Encrypt certificate management
  - Access lists and basic authentication
  - Redirection and stream host support
  - SSL passthrough support
- **Advantages**:
  - No YAML or config files required
  - Easiest reverse proxy setup for beginners
  - Wildcard and single-domain SSL support
- **Disadvantages/Limitations**:
  - Not suitable for very dynamic Docker environments
  - Less powerful routing rules than Traefik or Caddy
  - Requires manual updates when new services are added

**Deploy**:
```
nginx-proxy-manager
```

---

### Traefik

Cloud-native, dynamic reverse proxy and load balancer with automatic Docker discovery.

- **Category**: Networking / Reverse Proxy
- **GitHub**: https://github.com/traefik/traefik
- **Docker Image**: `traefik`
- **Default Port**: 8080 (dashboard)
- **Key Features**:
  - Automatic service discovery via Docker labels
  - Dynamic configuration — no restarts needed
  - Built-in Let's Encrypt with wildcard support
  - Middleware for authentication, rate limiting, headers
  - Dashboard for routing visibility
- **Advantages**:
  - Zero-touch routing when containers start/stop
  - Excellent Docker and Kubernetes integration
  - Highly extensible middleware system
- **Disadvantages/Limitations**:
  - Steeper learning curve than Nginx Proxy Manager
  - YAML/TOML configuration can be verbose
  - Dashboard is read-only (no GUI management)

**Deploy**:
```
traefik
```

---

## Networking - VPN

### Gluetun

VPN client container that routes traffic from other containers through a VPN tunnel.

- **Category**: Networking / VPN
- **GitHub**: https://github.com/qdm12/gluetun
- **Docker Image**: `qmcgaw/gluetun`
- **Default Port**: 8888 (HTTP proxy)
- **Key Features**:
  - Supports 30+ VPN providers (Mullvad, NordVPN, PIA, etc.)
  - Routes other containers through it via `network_mode: service:`
  - Built-in HTTP and SOCKS5 proxy
  - DNS over TLS with ad blocking
  - Kill switch prevents unencrypted leaks
- **Advantages**:
  - Single container provides VPN for many services
  - Keeps credentials and VPN logic isolated
  - Actively maintained with provider updates
- **Disadvantages/Limitations**:
  - Requires a paid VPN provider subscription
  - Requires `NET_ADMIN` capability (privileged networking)
  - Performance overhead from VPN tunneling

**Deploy**:
```
gluetun
```

---

### Headscale

Self-hosted control server compatible with the Tailscale client.

- **Category**: Networking / VPN
- **GitHub**: https://github.com/juanfont/headscale
- **Docker Image**: `headscale/headscale`
- **Default Port**: 8080
- **Key Features**:
  - WireGuard-based mesh VPN via Tailscale clients
  - Self-hosted — no dependency on Tailscale's servers
  - MagicDNS for easy hostname resolution
  - User and node management via CLI or API
  - ACL-based access control
- **Advantages**:
  - Full control over your mesh VPN infrastructure
  - Works with existing Tailscale clients (iOS, Android, Windows, Linux)
  - No usage or node limits
- **Disadvantages/Limitations**:
  - CLI-only management (no official web UI)
  - Some Tailscale features not yet supported (e.g., Taildrive)
  - Requires a public endpoint for DERP/relay

**Deploy**:
```
headscale
```

---

### WireGuard

Fast, modern VPN using the WireGuard protocol.

- **Category**: Networking / VPN
- **GitHub**: https://github.com/linuxserver/docker-wireguard
- **Docker Image**: `linuxserver/wireguard`
- **Default Port**: 51820/UDP
- **Key Features**:
  - Minimal, high-performance VPN protocol
  - Simple peer configuration with QR code generation
  - Supports road warrior (client) and site-to-site modes
  - Built into the Linux kernel since 5.6
  - Very low handshake and connection latency
- **Advantages**:
  - Fastest VPN protocol available
  - Extremely simple cryptographic design
  - Wide client support across all platforms
- **Disadvantages/Limitations**:
  - Requires kernel module (`CAP_NET_ADMIN`)
  - No built-in web UI (use wg-easy for a GUI)
  - Static IP allocation; no built-in DNS management

**Deploy**:
```
wireguard
```

---

## Productivity - Bookmarks

### Linkwarden

Self-hosted bookmark manager with full-page archiving and collection organization.

- **Category**: Productivity / Bookmarks
- **GitHub**: https://github.com/linkwarden/linkwarden
- **Docker Image**: `ghcr.io/linkwarden/linkwarden`
- **Default Port**: 3300
- **Key Features**:
  - Archive full page snapshots (HTML, screenshot, PDF)
  - Tag and collection-based organization
  - Full-text search across bookmarks and archives
  - Multi-user with collaborative collections
  - Browser extension for quick saving
- **Advantages**:
  - Archives pages locally — links never go dead
  - Modern, clean interface
  - Multi-user collaboration support
- **Disadvantages/Limitations**:
  - Heavier than simple bookmark managers (needs Playwright for archiving)
  - Relatively new project; some features still maturing

**Deploy**:
```
linkwarden
```

---

### Wallabag

Read-it-later service for saving articles and reading them offline.

- **Category**: Productivity / Bookmarks
- **GitHub**: https://github.com/wallabag/wallabag
- **Docker Image**: `wallabag/wallabag`
- **Default Port**: 8760
- **Key Features**:
  - Save articles for offline reading
  - Cleans article content for distraction-free reading
  - Mobile apps for iOS and Android
  - Browser extension for one-click saving
  - Export to EPUB, PDF, and CSV
- **Advantages**:
  - Excellent article extraction quality
  - Works offline once synced
  - Long-established project with proven stability
- **Disadvantages/Limitations**:
  - PHP stack is heavier than newer alternatives
  - UI is functional but dated
  - Not designed as a full bookmark manager

**Deploy**:
```
wallabag
```

---

## Productivity - Notes

### Joplin Server

Backend sync server for the Joplin desktop and mobile note-taking applications.

- **Category**: Productivity / Notes
- **GitHub**: https://github.com/laurent22/joplin
- **Docker Image**: `joplin/server`
- **Default Port**: 22300
- **Key Features**:
  - Sync notes between Joplin desktop, iOS, and Android apps
  - End-to-end encryption support
  - Markdown notes with rich attachment support
  - Notebook and tag organization
  - Note sharing via public links
- **Advantages**:
  - Replaces Dropbox/OneDrive sync with a self-hosted server
  - Mature desktop and mobile clients
  - E2E encryption keeps data private
- **Disadvantages/Limitations**:
  - Server is only useful alongside Joplin clients
  - No native web editor (use Joplin desktop for editing)
  - Multi-user requires a paid license for the hosted version (self-hosted is free)

**Deploy**:
```
joplin
```

---

### Outline

Modern, Notion-like wiki and knowledge base for teams.

- **Category**: Productivity / Notes
- **GitHub**: https://github.com/outline/outline
- **Docker Image**: `outlinewiki/outline`
- **Default Port**: 3900
- **Key Features**:
  - Rich text editing with slash commands
  - Nested documents and collections
  - Real-time collaborative editing
  - Full-text search
  - OAuth integration (Google, Slack, Okta, etc.)
- **Advantages**:
  - Beautiful, modern UI comparable to Notion
  - Great team collaboration features
  - Markdown import/export
- **Disadvantages/Limitations**:
  - Requires external OAuth provider for authentication
  - Heavier setup (needs Redis, Postgres, and S3/MinIO)
  - Not ideal for personal single-user note-taking

**Deploy**:
```
outline
```

---

### Memos

Lightweight, Twitter-like memo and journal application for quick notes.

- **Category**: Productivity / Notes
- **GitHub**: https://github.com/usememos/memos
- **Docker Image**: `neosmemo/memos`
- **Default Port**: 5230
- **Key Features**:
  - Quick, tag-based short-form notes
  - Markdown support with image attachments
  - Timeline view of past memos
  - Public and private memo visibility
  - REST API for integrations
- **Advantages**:
  - Extremely lightweight — single binary with SQLite
  - Great for capturing quick thoughts and ideas
  - Zero-friction posting experience
- **Disadvantages/Limitations**:
  - Not designed for long-form documents
  - Limited organization features compared to Outline or Joplin
  - Search is basic

**Deploy**:
```
memos
```

---

## Productivity - Tasks

### Vikunja

Open source, self-hosted task manager and to-do app.

- **Category**: Productivity / Tasks
- **GitHub**: https://github.com/go-vikunja/vikunja
- **Docker Image**: `vikunja/vikunja`
- **Default Port**: 3456
- **Key Features**:
  - List, Kanban, table, and Gantt views
  - Task assignments, due dates, and labels
  - Project sharing and collaboration
  - CalDAV support for calendar integration
  - REST API and CLI
- **Advantages**:
  - All-in-one binary — very easy to deploy
  - Open source alternative to Todoist/TickTick
  - Good mobile apps
- **Disadvantages/Limitations**:
  - Smaller community than established alternatives
  - Some features (Gantt chart) are basic
  - Mobile apps less polished than commercial competitors

**Deploy**:
```
vikunja
```

---

### Plane

Open source project management tool, alternative to Linear, Jira, and Asana.

- **Category**: Productivity / Tasks
- **GitHub**: https://github.com/makeplane/plane
- **Docker Image**: `makeplane/plane-frontend`
- **Default Port**: 8970
- **Key Features**:
  - Issue tracking with cycles (sprints) and modules
  - Multiple views: board, list, calendar, sheet
  - Analytics and reporting
  - Workspace and project hierarchy
  - Integrations via webhooks and API
- **Advantages**:
  - Feature-rich, comparable to Linear or Jira
  - Modern, fast interface
  - Active development with frequent releases
- **Disadvantages/Limitations**:
  - Multi-container setup (frontend, API, worker, database)
  - Self-hosted version may lag behind cloud version on features
  - Resource-intensive compared to simpler task managers

**Deploy**:
```
plane
```

---

## Server - Auth

### Authelia

Authentication and authorization portal providing 2FA and SSO for self-hosted services.

- **Category**: Server / Auth
- **GitHub**: https://github.com/authelia/authelia
- **Docker Image**: `authelia/authelia`
- **Default Port**: 9091
- **Key Features**:
  - Two-factor authentication (TOTP, WebAuthn, push)
  - Single sign-on via OpenID Connect
  - Forward authentication for Traefik/nginx
  - LDAP/Active Directory integration
  - Fine-grained access policies per domain
- **Advantages**:
  - Adds 2FA to any service behind a supported reverse proxy
  - OIDC provider for apps that support OAuth
  - Mature, well-documented project
- **Disadvantages/Limitations**:
  - Configuration is complex YAML
  - Requires a compatible reverse proxy (Traefik, nginx, Caddy)
  - Some OIDC features require specific setup

**Deploy**:
```
authelia
```

---

## Server - Dashboards

### Homepage

Highly customizable YAML-configured service dashboard.

- **Category**: Server / Dashboards
- **GitHub**: https://github.com/gethomepage/homepage
- **Docker Image**: `ghcr.io/gethomepage/homepage`
- **Default Port**: 3050
- **Key Features**:
  - Service widgets with live status and stats
  - Docker integration to auto-discover containers
  - Bookmarks, quick search, and weather widgets
  - YAML configuration with hot reload
  - Multi-group layout support
- **Advantages**:
  - Very fast and lightweight
  - Rich widget library for *arr, Jellyfin, etc.
  - Clean, modern design
- **Disadvantages/Limitations**:
  - YAML-only configuration (no GUI)
  - Some widgets require API keys to be configured
  - Less drag-and-drop friendly than Homarr

**Deploy**:
```
homepage
```

---

### Homarr

Drag-and-drop app dashboard with built-in app integrations.

- **Category**: Server / Dashboards
- **GitHub**: https://github.com/ajnart/homarr
- **Docker Image**: `ghcr.io/ajnart/homarr`
- **Default Port**: 7575
- **Key Features**:
  - Drag-and-drop widget layout
  - App integration tiles (Sonarr, Radarr, Jellyfin, etc.)
  - Docker container status and management
  - Search bar with multiple search engines
  - User authentication
- **Advantages**:
  - No YAML required — fully GUI-configured
  - Good app integrations out of the box
  - Easy to set up and customize
- **Disadvantages/Limitations**:
  - Heavier than Homepage
  - Some integrations are less feature-rich than Homepage widgets
  - Slower development pace in recent versions

**Deploy**:
```
homarr
```

---

### Portainer

Full-featured web UI for managing Docker containers, images, networks, and volumes.

- **Category**: Server / Dashboards
- **GitHub**: https://github.com/portainer/portainer
- **Docker Image**: `portainer/portainer-ce`
- **Default Port**: 9000
- **Key Features**:
  - Full Docker and Docker Swarm management UI
  - Stack deployment from Git or the editor
  - Container logs, terminal access, and stats
  - User and team management
  - Kubernetes support in the EE edition
- **Advantages**:
  - Best Docker management UI available
  - Free Community Edition covers most needs
  - Manage multiple Docker hosts from one UI
- **Disadvantages/Limitations**:
  - Some features locked to paid Business Edition
  - Can be overkill for simple single-host setups
  - Requires access to the Docker socket (high privilege)

**Deploy**:
```
portainer
```

---

## Server - Management

### Watchtower

Automatically updates running Docker containers when new images are published.

- **Category**: Server / Management
- **GitHub**: https://github.com/containrrr/watchtower
- **Docker Image**: `containrrr/watchtower`
- **Default Port**: None
- **Key Features**:
  - Polls registries for new image versions
  - Automatically pulls and restarts updated containers
  - Include/exclude specific containers
  - Scheduled update windows (cron syntax)
  - Notification support (Slack, email, ntfy, etc.)
- **Advantages**:
  - Zero-touch container updates
  - Configurable schedules to minimize downtime
  - Simple setup — just point at the Docker socket
- **Disadvantages/Limitations**:
  - Requires Docker socket access (high privilege)
  - Rolling updates without testing can break things
  - Not suitable for production environments where changes need review

**Deploy**:
```
watchtower
```

---

### Dozzle

Real-time Docker container log viewer with a clean web interface.

- **Category**: Server / Management
- **GitHub**: https://github.com/amir20/dozzle
- **Docker Image**: `amir20/dozzle`
- **Default Port**: 8940
- **Key Features**:
  - Real-time log streaming for all containers
  - Search and filter log output
  - Multi-host log aggregation
  - No database — streams logs directly from Docker
  - Dark mode and clean UI
- **Advantages**:
  - Zero configuration — attach to Docker socket and go
  - Extremely lightweight (no storage)
  - Great for quick log inspection without SSH
- **Disadvantages/Limitations**:
  - No log persistence (historical logs only via Docker's own log driver)
  - Not a replacement for a full log aggregation stack (ELK, Loki)
  - Requires Docker socket access

**Deploy**:
```
dozzle
```

---

## Miscellaneous

### qBittorrent

Full-featured, open source BitTorrent client with a web UI.

- **Category**: Miscellaneous
- **GitHub**: https://github.com/qbittorrent/qBittorrent
- **Docker Image**: `linuxserver/qbittorrent`
- **Default Port**: 8085
- **Key Features**:
  - Web UI accessible from any browser
  - Sequential and prioritized downloading
  - RSS feed with auto-downloading rules
  - Category and tag organization
  - VPN-friendly via Gluetun network_mode
- **Advantages**:
  - No tracking or ads (unlike some torrent clients)
  - Excellent Sonarr/Radarr integration
  - Lightweight compared to Deluge or Transmission
- **Disadvantages/Limitations**:
  - Web UI less polished than the desktop client
  - Must be paired with Gluetun or VPN to protect IP

**Deploy**:
```
qbittorrent
```

---

### SABnzbd

Usenet binary downloader with web-based management.

- **Category**: Miscellaneous
- **GitHub**: https://github.com/sabnzbd/sabnzbd
- **Docker Image**: `linuxserver/sabnzbd`
- **Default Port**: 8080
- **Key Features**:
  - Automated Usenet NZB downloading and unpacking
  - Integration with Sonarr, Radarr, Lidarr
  - Download queue management and scheduling
  - Par2 repair and RAR extraction
  - Notification support
- **Advantages**:
  - Best-in-class Usenet downloader
  - Excellent *arr integration
  - Stable and actively maintained
- **Disadvantages/Limitations**:
  - Requires a paid Usenet provider subscription
  - Usenet is region-limited (some content less available)
  - Not as beginner-friendly as torrent clients

**Deploy**:
```
sabnzbd
```

---

### Autobrr

Automated download client triggered by IRC announce channels.

- **Category**: Miscellaneous
- **GitHub**: https://github.com/autobrr/autobrr
- **Docker Image**: `ghcr.io/autobrr/autobrr`
- **Default Port**: 7474
- **Key Features**:
  - Monitors IRC announce channels for new releases
  - Filter-based auto-download rules
  - Integrates with qBittorrent, Deluge, SABnzbd, Sonarr, Radarr
  - Freeleech and ratio-aware filtering
  - Notifications for grabbed releases
- **Advantages**:
  - Downloads releases the moment they are announced
  - Excellent for private tracker ratio management
  - Highly configurable filter system
- **Disadvantages/Limitations**:
  - Primarily useful with private torrent trackers
  - Requires IRC configuration which can be complex
  - Less useful for public tracker content

**Deploy**:
```
autobrr
```

---

### Recyclarr

Syncs TRaSH Guides quality profiles and custom formats to Sonarr and Radarr automatically.

- **Category**: Miscellaneous
- **GitHub**: https://github.com/recyclarr/recyclarr
- **Docker Image**: `ghcr.io/recyclarr/recyclarr`
- **Default Port**: None
- **Key Features**:
  - Syncs TRaSH Guides recommended quality profiles
  - Automatically updates custom formats in Sonarr/Radarr
  - YAML configuration for fine-grained control
  - Scheduled sync via cron
  - Dry-run mode for safe previews
- **Advantages**:
  - Eliminates manual TRaSH Guide setup
  - Keeps profiles up-to-date as guides evolve
  - Simple YAML config
- **Disadvantages/Limitations**:
  - Config-file only (no web UI)
  - Requires understanding of TRaSH Guides concepts
  - Only supports Sonarr and Radarr (not Lidarr)

**Deploy**:
```
recyclarr
```

---

### FlareSolverr

Proxy server for bypassing Cloudflare and DDoS-Guard protection, used by indexers.

- **Category**: Miscellaneous
- **GitHub**: https://github.com/FlareSolverr/FlareSolverr
- **Docker Image**: `ghcr.io/flaresolverr/flaresolverr`
- **Default Port**: 8191
- **Key Features**:
  - Solves Cloudflare JavaScript challenges automatically
  - Used by Prowlarr and Jackett for protected indexers
  - Headless browser-based challenge solving
  - Session management for persistent cookies
  - Simple REST API
- **Advantages**:
  - Enables access to Cloudflare-protected indexers
  - Drop-in support in Prowlarr
  - No manual CAPTCHA solving required
- **Disadvantages/Limitations**:
  - High memory usage (runs a full browser instance)
  - May break when Cloudflare updates its challenge mechanism
  - Should not be exposed publicly

**Deploy**:
```
flaresolverr
```
