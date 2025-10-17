#!/bin/bash
# -----------------------------------------------------------------------------
# Script: deploy_repos.sh
# Description: Configures essential Arch Linux repositories (multilib, chaotic-aur, xerolinux)
# and installs the 'paru' AUR helper using secure, bulletproof Bash methodology.
# -----------------------------------------------------------------------------

# --- Strict Mode and Safety Checks ---
set -euo pipefail

LOG_FILE="/var/log/deploy_repos.log"
CHAOTIC_KEYRING_URL="https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst"
CHAOTIC_MIRRORLIST_URL="https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst"
TEMP_DIR=$(mktemp -d)

# Logging function
log() {
    local level="$1"
    local message="$2"
    echo "[$level] $message" | tee -a "$LOG_FILE"
}

cleanup() {
    log "INFO" "Cleaning up temporary directory: $TEMP_DIR"
    rm -rf "$TEMP_DIR"
    log "INFO" "Script finished execution with status $?."
}

# Trap exit signal to ensure cleanup runs on success or failure
trap cleanup EXIT

# Check for root permissions
check_root() {
    if [[ $(id -u) -ne 0 ]]; then
        log "ERROR" "This script must be run as root (EUID=0)."
        exit 1
    fi
    log "INFO" "Root check passed."
}

# --- Configuration Functions ---

enable_multilib() {
    log "INFO" "1. Enabling [multilib] repository..."
    # Use sed to safely uncomment the multilib section and its Include line.[2, 3]
    # Check if the [multilib] header is currently commented out
    if grep -q '^#\[multilib\]' /etc/pacman.conf; then
        sed -i '/\[multilib\]/{
            s/^#//;
            n;
            s/^#Include/Include/
        }' /etc/pacman.conf
        log "INFO" "Successfully enabled multilib in /etc/pacman.conf."
    else
        log "WARNING" "[multilib] appears to be already enabled. Skipping modification."
    fi
}

install_chaotic_aur() {
    log "INFO" "2. Installing Chaotic-AUR keyring and repository definition."

    # Install the keyring and mirrorlist packages directly via pacman -U, bypassing keyservers.[10, 12]
    log "INFO" "Downloading keyring and mirrorlist packages..."
    curl -sL -o "$TEMP_DIR/chaotic-keyring.pkg.tar.zst" "$CHAOTIC_KEYRING_URL"
    curl -sL -o "$TEMP_DIR/chaotic-mirrorlist.pkg.tar.zst" "$CHAOTIC_MIRRORLIST_URL"
    
    log "INFO" "Installing packages via pacman -U to establish trust..."
    pacman -U --noconfirm "$TEMP_DIR/chaotic-keyring.pkg.tar.zst" "$TEMP_DIR/chaotic-mirrorlist.pkg.tar.zst"
    
    # Append the repository block to the end, ensuring lowest precedence.[8, 11]
    if! grep -q '\[chaotic-aur\]' /etc/pacman.conf; then
        log "INFO" "Appending [chaotic-aur] definition to pacman.conf."
        echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | tee -a /etc/pacman.conf > /dev/null
    else
        log "WARNING" "[chaotic-aur] definition already present. Skipping append."
    fi
}

install_xerolinux() {
    log "INFO" "3. Configuring Xerolinux repository with explicit SigLevel."
    # Setting SigLevel = Optional TrustAll bypasses the need for GPG key import by the administrator.
    # Note: The use of TrustAll reduces security and is generally discouraged for unknown repositories.
    XEROLINUX_REPO_BLOCK="\n[xerolinux]\nSigLevel = Optional TrustAll\nServer = https://repos.xerolinux.xyz/\$repo/\$arch"

    if! grep -q '\[xerolinux\]' /etc/pacman.conf; then
        log "INFO" "Appending [xerolinux] definition to pacman.conf."
        echo -e "$XEROLININUX_REPO_BLOCK" | tee -a /etc/pacman.conf > /dev/null [13]
    else
        log "WARNING" "[xerolinux] definition already present. Skipping append."
    fi
}

sync_databases() {
    log "INFO" "4. Synchronizing package databases and performing initial system upgrade (pacman -Syyu)."
    # Synchronization ensures all databases are refreshed and the newly installed Chaotic-AUR keys are trusted.
    pacman -Syyu --noconfirm
}

install_aur_helper() {
    log "INFO" "5. Installing Paru AUR helper."
    # Leveraging the pre-built binary package available in Chaotic-AUR for speed.[17]
    log "INFO" "Installing paru directly using pacman."
    pacman -S --noconfirm paru
    log "INFO" "Paru installed successfully. AUR is now accessible."
}

# --- Execution Flow ---
check_root

log "INFO" "Starting Arch Linux repository configuration and AUR helper deployment."

enable_multilib
install_chaotic_aur
install_xerolinux
sync_databases
install_aur_helper

log "SUCCESS" "All required repositories and the 'paru' AUR helper have been deployed."
log "SUCCESS" "Administrator verification required for external binary repository integrity."

exit 0
