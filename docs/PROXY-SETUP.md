# Reverse Proxy Setup

> Generated 2026-03-11 by `scripts/reverse-proxy-configurator.py`  
> Backend: **traefik** | Domain: **myserver.com**

## Services exposed via reverse proxy

| Service | Host | Description |
|---------|------|-------------|
| jellyfin | `jellyfin.myserver.com` | Open source media server |
| sonarr | `sonarr.myserver.com` | TV series management |
| radarr | `radarr.myserver.com` | Movie management |
| bazarr | `bazarr.myserver.com` | Subtitle management |
| jellyseerr | `jellyseerr.myserver.com` | Media request management |
| prowlarr | `prowlarr.myserver.com` | Indexer manager |
| maintainerr | `maintainerr.myserver.com` | Media cleanup rules |
| lidarr | `lidarr.myserver.com` | Music management |
| slskd | `slskd.myserver.com` | Soulseek client |
| piwigo | `piwigo.myserver.com` | Photo gallery |
| adguard | `adguard.myserver.com` | DNS ad blocker |
| pihole | `pihole.myserver.com` | DNS ad blocker |
| nginx-proxy-manager | `nginx-proxy-manager.myserver.com` | Reverse proxy with GUI |
| traefik | `traefik.myserver.com` | Cloud native proxy |
| beszel | `beszel.myserver.com` | Lightweight server monitor |
| uptime-kuma | `uptime-kuma.myserver.com` | Status page monitor |
| gluetun | `gluetun.myserver.com` | VPN client container |
| headscale | `headscale.myserver.com` | Self-hosted Tailscale control server |
| openwebui | `openwebui.myserver.com` | Web UI for LLMs |
| n8n | `n8n.myserver.com` | Workflow automation |
| anythingllm | `anythingllm.myserver.com` | Private LLM workspace |
| gitea | `gitea.myserver.com` | Self-hosted Git service |
| code-server | `code-server.myserver.com` | VS Code in browser |
| semaphore | `semaphore.myserver.com` | Ansible UI |
| nextcloud | `nextcloud.myserver.com` | File sharing and collaboration |
| filebrowser | `filebrowser.myserver.com` | Web file manager |
| minio | `minio.myserver.com` | S3-compatible object storage |
| matrix-synapse | `matrix.myserver.com` | Matrix homeserver |
| ntfy | `ntfy.myserver.com` | Push notifications |
| gotify | `gotify.myserver.com` | Self-hosted notifications |
| joplin | `joplin.myserver.com` | Note-taking server |
| outline | `outline.myserver.com` | Wiki and notes |
| memos | `memos.myserver.com` | Memo/journal |
| linkwarden | `linkwarden.myserver.com` | Bookmark manager |
| wallabag | `wallabag.myserver.com` | Read-later service |
| vikunja | `vikunja.myserver.com` | Task manager |
| plane | `plane.myserver.com` | Project management |
| homepage | `homepage.myserver.com` | Service dashboard |
| homarr | `homarr.myserver.com` | App dashboard |
| portainer | `portainer.myserver.com` | Docker management UI |
| dozzle | `dozzle.myserver.com` | Container log viewer |
| authelia | `auth.myserver.com` | Authentication portal |
| qbittorrent | `qbittorrent.myserver.com` | BitTorrent client |
| sabnzbd | `sabnzbd.myserver.com` | Usenet downloader |
| autobrr | `autobrr.myserver.com` | Automatic download |
| flaresolverr | `flaresolverr.myserver.com` | Cloudflare bypass proxy |

## Quick Start

1. Copy `stacks/proxy-traefik.yaml` to your deployment directory.
2. Ensure your `.env` file has `BASE_DOMAIN` and `DEFAULT_NETWORK` set.
3. Start the proxy stack:

```bash
docker compose -f stacks/proxy-traefik.yaml up -d
```

## Backend-specific notes

### Traefik
- Dynamic config is written to `stacks/traefik-dynamic.yaml`.
- Mount it in your Traefik container under `/etc/traefik/dynamic/`.
- `tls.certresolver` defaults to `letsencrypt` — adjust as needed.
