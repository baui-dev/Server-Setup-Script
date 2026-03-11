# Service Startup Plan

> Generated 2026-03-11 by `scripts/generate-dependency-graph.py`

Start services in the order shown below. Each wave can be started in parallel.

## Wave 1

| Service | Category | Description | Requires |
|---------|----------|-------------|---------|
| adguard | networking | DNS ad blocker | — |
| anythingllm | ai | Private LLM workspace | — |
| authelia | server | Authentication portal | — |
| autobrr | misc | Automatic download | — |
| bazarr | media | Subtitle management | — |
| beszel | networking | Lightweight server monitor | — |
| code-server | development | VS Code in browser | — |
| dozzle | server | Container log viewer | — |
| filebrowser | files | Web file manager | — |
| flaresolverr | misc | Cloudflare bypass proxy | — |
| gitea | development | Self-hosted Git service | — |
| gluetun | networking | VPN client container | — |
| gotify | communication | Self-hosted notifications | — |
| headscale | networking | Self-hosted Tailscale control server | — |
| homarr | server | App dashboard | — |
| homepage | server | Service dashboard | — |
| jellyfin | media | Open source media server | — |
| jellyseerr | media | Media request management | — |
| joplin | productivity | Note-taking server | — |
| lidarr | media | Music management | — |
| linkwarden | productivity | Bookmark manager | — |
| maintainerr | media | Media cleanup rules | — |
| matrix-synapse | communication | Matrix homeserver | — |
| memos | productivity | Memo/journal | — |
| minio | files | S3-compatible object storage | — |
| n8n | ai | Workflow automation | — |
| nextcloud | files | File sharing and collaboration | — |
| nginx-proxy-manager | networking | Reverse proxy with GUI | — |
| ntfy | communication | Push notifications | — |
| openwebui | ai | Web UI for LLMs | — |
| outline | productivity | Wiki and notes | — |
| pihole | networking | DNS ad blocker | — |
| piwigo | media | Photo gallery | — |
| plane | productivity | Project management | — |
| portainer | server | Docker management UI | — |
| prowlarr | media | Indexer manager | — |
| qbittorrent | misc | BitTorrent client | — |
| radarr | media | Movie management | — |
| recyclarr | misc | Quality profiles sync | — |
| sabnzbd | misc | Usenet downloader | — |
| semaphore | development | Ansible UI | — |
| slskd | media | Soulseek client | — |
| sonarr | media | TV series management | — |
| traefik | networking | Cloud native proxy | — |
| unbound | networking | DNS resolver | — |
| uptime-kuma | networking | Status page monitor | — |
| vikunja | productivity | Task manager | — |
| wallabag | productivity | Read-later service | — |
| watchtower | server | Auto container updates | — |
| wireguard | networking | WireGuard VPN server | — |

## Legend

| Shape | Meaning |
|-------|---------|
| Rectangle | HTTP-exposing service |
| Diamond   | Database / cache |
| Ellipse   | Other / background service |
