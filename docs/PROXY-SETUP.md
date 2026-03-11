# Reverse Proxy Setup

> Generated 2026-03-11 by `scripts/reverse-proxy-configurator.py`  
> Backend: **godoxy** | Domain: **${BASE_DOMAIN}**

## Services exposed via reverse proxy

| Service | Host | Description |
|---------|------|-------------|
| jellyfin | `jellyfin.${BASE_DOMAIN}` | Open source media server |
| sonarr | `sonarr.${BASE_DOMAIN}` | TV series management |
| radarr | `radarr.${BASE_DOMAIN}` | Movie management |
| bazarr | `bazarr.${BASE_DOMAIN}` | Subtitle management |
| jellyseerr | `jellyseerr.${BASE_DOMAIN}` | Media request management |
| prowlarr | `prowlarr.${BASE_DOMAIN}` | Indexer manager |
| maintainerr | `maintainerr.${BASE_DOMAIN}` | Media cleanup rules |
| lidarr | `lidarr.${BASE_DOMAIN}` | Music management |
| slskd | `slskd.${BASE_DOMAIN}` | Soulseek client |
| piwigo | `piwigo.${BASE_DOMAIN}` | Photo gallery |
| adguard | `adguard.${BASE_DOMAIN}` | DNS ad blocker |
| pihole | `pihole.${BASE_DOMAIN}` | DNS ad blocker |
| nginx-proxy-manager | `nginx-proxy-manager.${BASE_DOMAIN}` | Reverse proxy with GUI |
| traefik | `traefik.${BASE_DOMAIN}` | Cloud native proxy |
| beszel | `beszel.${BASE_DOMAIN}` | Lightweight server monitor |
| uptime-kuma | `uptime-kuma.${BASE_DOMAIN}` | Status page monitor |
| gluetun | `gluetun.${BASE_DOMAIN}` | VPN client container |
| headscale | `headscale.${BASE_DOMAIN}` | Self-hosted Tailscale control server |
| openwebui | `openwebui.${BASE_DOMAIN}` | Web UI for LLMs |
| n8n | `n8n.${BASE_DOMAIN}` | Workflow automation |
| anythingllm | `anythingllm.${BASE_DOMAIN}` | Private LLM workspace |
| gitea | `gitea.${BASE_DOMAIN}` | Self-hosted Git service |
| code-server | `code-server.${BASE_DOMAIN}` | VS Code in browser |
| semaphore | `semaphore.${BASE_DOMAIN}` | Ansible UI |
| nextcloud | `nextcloud.${BASE_DOMAIN}` | File sharing and collaboration |
| filebrowser | `filebrowser.${BASE_DOMAIN}` | Web file manager |
| minio | `minio.${BASE_DOMAIN}` | S3-compatible object storage |
| matrix-synapse | `matrix.${BASE_DOMAIN}` | Matrix homeserver |
| ntfy | `ntfy.${BASE_DOMAIN}` | Push notifications |
| gotify | `gotify.${BASE_DOMAIN}` | Self-hosted notifications |
| joplin | `joplin.${BASE_DOMAIN}` | Note-taking server |
| outline | `outline.${BASE_DOMAIN}` | Wiki and notes |
| memos | `memos.${BASE_DOMAIN}` | Memo/journal |
| linkwarden | `linkwarden.${BASE_DOMAIN}` | Bookmark manager |
| wallabag | `wallabag.${BASE_DOMAIN}` | Read-later service |
| vikunja | `vikunja.${BASE_DOMAIN}` | Task manager |
| plane | `plane.${BASE_DOMAIN}` | Project management |
| homepage | `homepage.${BASE_DOMAIN}` | Service dashboard |
| homarr | `homarr.${BASE_DOMAIN}` | App dashboard |
| portainer | `portainer.${BASE_DOMAIN}` | Docker management UI |
| dozzle | `dozzle.${BASE_DOMAIN}` | Container log viewer |
| authelia | `auth.${BASE_DOMAIN}` | Authentication portal |
| qbittorrent | `qbittorrent.${BASE_DOMAIN}` | BitTorrent client |
| sabnzbd | `sabnzbd.${BASE_DOMAIN}` | Usenet downloader |
| autobrr | `autobrr.${BASE_DOMAIN}` | Automatic download |
| flaresolverr | `flaresolverr.${BASE_DOMAIN}` | Cloudflare bypass proxy |

## Quick Start

1. Copy `stacks/proxy-godoxy.yaml` to your deployment directory.
2. Ensure your `.env` file has `BASE_DOMAIN` and `DEFAULT_NETWORK` set.
3. Start the proxy stack:

```bash
docker compose -f stacks/proxy-godoxy.yaml up -d
```

## Backend-specific notes

### godoxy
Labels are applied via the `proxy.*` label namespace.
Ensure your godoxy instance is running on the same Docker network.
