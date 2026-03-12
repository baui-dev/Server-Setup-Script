#!/usr/bin/env fish
cd /home/nvme/Projects/Server-Setup-Script

set copied 0
set scaffolded 0
set unresolved 0
set processed 0
set report /tmp/yaml_fill_report.txt
: > $report

for p in (find . -type f \( -name '*.yaml' -o -name '*.yml' \) -empty | sort)
  set processed (math $processed + 1)
  set rel (string replace -r '^\./' '' $p)
  set base (basename $p)

  set best ''
  set best_size 0
  for c in (find . -type f -name $base ! -path $p ! -empty)
    set sz (wc -c < $c)
    if test $sz -gt $best_size
      set best_size $sz
      set best $c
    end
  end

  if test -n "$best"
    cat $best > $p
    set copied (math $copied + 1)
    echo COPIED'|'$rel'|'(string replace -r '^\./' '' $best) >> $report
    continue
  end

  set stem (path change-extension '' (basename $p))
  set service (string lower (string trim $stem))
  set service (string replace -ra '[^a-z0-9]+' '-' $service)
  set service (string trim -c '-' $service)
  if test -z "$service"
    set service generic-service
  end

  set port_var (string upper (string replace -ra '[^a-z0-9]+' '_' $service))
  set data_group (dirname $rel)
  set data_group (string replace -r '^compose/stacks/' '' $data_group)

  printf '%s\n' \
    "# $service" \
    '# Restored scaffold generated from repository conventions.' \
    '# Replace image/ports/volumes with the real upstream service details if needed.' \
    '' \
    'services:' \
    "  $service:" \
    '    image: ghcr.io/linuxserver/baseimage-alpine:latest' \
    "    container_name: $service" \
    "    hostname: $service" \
    '    restart: unless-stopped' \
    '    environment:' \
    '      - TZ=${TZ}' \
    '      - PUID=${PUID:-1000}' \
    '      - PGID=${PGID:-1000}' \
    '    volumes:' > $p

  printf '      - ${DOCKER_DATA:-/srv/dockerdata}/%s/%s/config:/config\n' $data_group $service >> $p
  printf '%s\n' '    ports:' >> $p
  printf '      - ${PORT_%s:-18080}:8080\n' $port_var >> $p

  if test -s $p
    set scaffolded (math $scaffolded + 1)
    echo SCAFFOLDED'|'$rel >> $report
  else
    set unresolved (math $unresolved + 1)
    echo UNRESOLVED'|'$rel >> $report
  end
end

echo processed=$processed
echo copied=$copied
echo scaffolded=$scaffolded
echo unresolved=$unresolved
echo remaining_empty=(find . -type f \( -name '*.yaml' -o -name '*.yml' \) -empty | wc -l)
echo report=$report
