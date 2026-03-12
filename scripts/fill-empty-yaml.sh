#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

copied=0
scaffolded=0
unresolved=0
processed=0
report="/tmp/yaml_fill_report.txt"
: > "$report"

while IFS= read -r p; do
  processed=$((processed + 1))
  rel="${p#./}"
  base="$(basename "$p")"

  best=""
  best_size=0
  while IFS= read -r c; do
    sz="$(wc -c < "$c")"
    if [ "$sz" -gt "$best_size" ]; then
      best_size="$sz"
      best="$c"
    fi
  done < <(find . -type f -name "$base" ! -path "$p" ! -empty)

  if [ -n "$best" ]; then
    cat "$best" > "$p"
    copied=$((copied + 1))
    echo "COPIED|$rel|${best#./}" >> "$report"
    continue
  fi

  stem="${base%.*}"
  service="$(echo "$stem" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  if [ -z "$service" ]; then
    service="generic-service"
  fi

  port_var="$(echo "$service" | tr '[:lower:]-' '[:upper:]_')"
  data_group="$(dirname "$rel" | sed -E 's#^compose/stacks/##')"

  cat > "$p" <<EOF
# $service
# Restored scaffold generated from repository conventions.
# Replace image/ports/volumes with the real upstream service details if needed.

services:
  $service:
    image: ghcr.io/linuxserver/baseimage-alpine:latest
    container_name: $service
    hostname: $service
    restart: unless-stopped
    environment:
      - TZ=
      - PUID=
      - PGID=
    volumes:
      - \\${DOCKER_DATA:-/srv/dockerdata}/$data_group/$service/config:/config
    ports:
      - \\${PORT_$port_var:-18080}:8080
EOF

  if [ -s "$p" ]; then
    scaffolded=$((scaffolded + 1))
    echo "SCAFFOLDED|$rel" >> "$report"
  else
    unresolved=$((unresolved + 1))
    echo "UNRESOLVED|$rel" >> "$report"
  fi
done < <(find . -type f \( -name '*.yaml' -o -name '*.yml' \) -empty | sort)

echo "processed=$processed"
echo "copied=$copied"
echo "scaffolded=$scaffolded"
echo "unresolved=$unresolved"
echo "remaining_empty=$(find . -type f \( -name '*.yaml' -o -name '*.yml' \) -empty | wc -l)"
echo "report=$report"
