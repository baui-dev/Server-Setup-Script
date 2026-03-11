# Compatibility Matrix

This document lists compatibility information for all services.

| Service | amd64 | arm64 | Min Docker | Privileged | Conflicts With |
|---------|-------|-------|------------|------------|----------------|
| jellyfin | ✓ | ✓ | 20.10 | No | - |
| sonarr | ✓ | ✓ | 20.10 | No | - |
| radarr | ✓ | ✓ | 20.10 | No | - |
| bazarr | ✓ | ✓ | 20.10 | No | - |
| jellyseerr | ✓ | ✓ | 20.10 | No | - |
| prowlarr | ✓ | ✓ | 20.10 | No | - |
| maintainerr | ✓ | ✓ | 20.10 | No | - |
| lidarr | ✓ | ✓ | 20.10 | No | - |
| slskd | ✓ | ✓ | 20.10 | No | - |
| piwigo | ✓ | ✓ | 20.10 | No | - |
| adguard | ✓ | ✓ | 20.10 | No | pihole |
| pihole | ✓ | ✓ | 20.10 | No | adguard |
| unbound | ✓ | ✓ | 20.10 | No | - |
| nginx-proxy-manager | ✓ | ✓ | 20.10 | No | - |
| traefik | ✓ | ✓ | 20.10 | No | - |
| beszel | ✓ | ✓ | 20.10 | No | - |
| uptime-kuma | ✓ | ✓ | 20.10 | No | - |
| gluetun | ✓ | ✓ | 20.10 | **Yes** | - |
| headscale | ✓ | ✓ | 20.10 | No | - |
| wireguard | ✓ | ✓ | 20.10 | **Yes** | - |
| openwebui | ✓ | ✓ | 20.10 | No | - |
| n8n | ✓ | ✓ | 20.10 | No | - |
| anythingllm | ✓ | ✓ | 20.10 | No | - |
| gitea | ✓ | ✓ | 20.10 | No | - |
| code-server | ✓ | ✓ | 20.10 | No | - |
| semaphore | ✓ | ✓ | 20.10 | No | - |
| nextcloud | ✓ | ✓ | 20.10 | No | - |
| filebrowser | ✓ | ✓ | 20.10 | No | - |
| minio | ✓ | ✓ | 20.10 | No | - |
| matrix-synapse | ✓ | ✓ | 20.10 | No | - |
| ntfy | ✓ | ✓ | 20.10 | No | - |
| gotify | ✓ | ✓ | 20.10 | No | - |
| joplin | ✓ | ✓ | 20.10 | No | - |
| outline | ✓ | ✓ | 20.10 | No | - |
| memos | ✓ | ✓ | 20.10 | No | - |
| linkwarden | ✓ | ✓ | 20.10 | No | - |
| wallabag | ✓ | ✓ | 20.10 | No | - |
| vikunja | ✓ | ✓ | 20.10 | No | - |
| plane | ✓ | ✓ | 20.10 | No | - |
| homepage | ✓ | ✓ | 20.10 | No | - |
| homarr | ✓ | ✓ | 20.10 | No | - |
| portainer | ✓ | ✓ | 20.10 | No | - |
| watchtower | ✓ | ✓ | 20.10 | No | - |
| dozzle | ✓ | ✓ | 20.10 | No | - |
| authelia | ✓ | ✓ | 20.10 | No | - |
| qbittorrent | ✓ | ✓ | 20.10 | No | - |
| sabnzbd | ✓ | ✓ | 20.10 | No | - |
| autobrr | ✓ | ✓ | 20.10 | No | - |
| recyclarr | ✓ | ✓ | 20.10 | No | - |
| flaresolverr | ✓ | ✓ | 20.10 | No | - |

## Port Reference

| Service | Default Port(s) | Protocol |
|---------|----------------|----------|
| jellyfin | 8096 | HTTP |
| sonarr | 8989 | HTTP |
| radarr | 7878 | HTTP |
| bazarr | 6767 | HTTP |
| jellyseerr | 5055 | HTTP |
| prowlarr | 9696 | HTTP |
| maintainerr | 6246 | HTTP |
| lidarr | 8686 | HTTP |
| slskd | 5030 | HTTP |
| piwigo | 8101 | HTTP |
| adguard | 3000 (UI), 53 (DNS) | HTTP/DNS |
| pihole | 8080 (UI), 53 (DNS) | HTTP/DNS |
| unbound | 5335 | DNS |
| nginx-proxy-manager | 81 (UI), 80, 443 | HTTP |
| traefik | 8080 (dashboard), 80, 443 | HTTP |
| beszel | 8090 | HTTP |
| uptime-kuma | 3001 | HTTP |
| gluetun | 8888 (proxy) | HTTP |
| headscale | 8080 | HTTP |
| wireguard | 51820 | UDP |
| openwebui | 3000 | HTTP |
| n8n | 5678 | HTTP |
| anythingllm | 3020 | HTTP |
| gitea | 3000 | HTTP |
| code-server | 8443 | HTTPS |
| semaphore | 3000 | HTTP |
| nextcloud | 8880 | HTTP |
| filebrowser | 8888 | HTTP |
| minio | 9000 (API), 9001 (UI) | HTTP |
| matrix-synapse | 8008 | HTTP |
| ntfy | 8840 | HTTP |
| gotify | 8850 | HTTP |
| joplin | 22300 | HTTP |
| outline | 3900 | HTTP |
| memos | 5230 | HTTP |
| linkwarden | 3300 | HTTP |
| wallabag | 8760 | HTTP |
| vikunja | 3456 | HTTP |
| plane | 8970 | HTTP |
| homepage | 3050 | HTTP |
| homarr | 7575 | HTTP |
| portainer | 9000 | HTTP |
| watchtower | — | — |
| dozzle | 8940 | HTTP |
| authelia | 9091 | HTTP |
| qbittorrent | 8085 | HTTP |
| sabnzbd | 8080 | HTTP |
| autobrr | 7474 | HTTP |
| recyclarr | — | — |
| flaresolverr | 8191 | HTTP |

## Known Conflicts

- **adguard** and **pihole** both bind to port 53 (DNS). Deploy only one DNS ad-blocker at a time.
- Multiple services default to port **3000**: `adguard` (UI), `openwebui`, `gitea`, `semaphore`. Change the corresponding `PORT_*` variable in `.env` if running more than one.
- **sabnzbd** and **pihole** both default their web UI to port **8080**. Adjust one via `.env`.
- **gluetun** and **wireguard** both require `NET_ADMIN` / privileged networking. They can coexist but must each have their own network namespace.
- **traefik** and **nginx-proxy-manager** serve the same role. Deploy only one reverse proxy unless you have a specific reason to run both.
