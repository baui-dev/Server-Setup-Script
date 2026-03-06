#!/bin/bash
# APT source list management functions
# Provides: add_docker_apt_source(), add_alvistack_apt_source()

# Add Docker's official APT repository for Debian.
add_docker_apt_source() {
    local distro_codename
    distro_codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"

    if [[ -z "$distro_codename" ]]; then
        echo "[ERROR] Cannot determine OS codename from /etc/os-release" >&2
        return 1
    fi

    apt-get install -y curl ca-certificates >/dev/null 2>&1 || true

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/debian/gpg" \
        -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/debian ${distro_codename} stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq
    echo "Docker APT source added for Debian ${distro_codename}."
}

# Add Alvistack's repository (up-to-date Podman packages for Debian).
add_alvistack_apt_source() {
    local version_id
    # shellcheck disable=SC1091
    source /etc/os-release
    version_id="${VERSION_ID:-12}"

    curl -fsSL \
        "https://downloadcontent.opensuse.org/repositories/home:/alvistack/Debian_${version_id}/Release.key" \
        | gpg --dearmor \
        | tee /etc/apt/trusted.gpg.d/alvistack.gpg > /dev/null

    echo "deb https://downloadcontent.opensuse.org/repositories/home:/alvistack/Debian_${version_id}/ /" \
        | tee /etc/apt/sources.list.d/alvistack.list > /dev/null

    apt-get update -qq
    echo "Alvistack APT source added for Debian ${version_id}."
}
