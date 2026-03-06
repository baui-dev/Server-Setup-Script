#!/bin/bash
# Security hardening configuration module
# Provides: prompt_security_config(), apply_security_hardening()
# Reads: SECURITY_HARDENING, SECURITY_FAIL2BAN, SECURITY_APPARMOR,
#        SECURITY_AUDITD, SECURITY_AIDE, SECURITY_AUTO_UPDATES, SSH_PORT

prompt_security_config() {
    local inp

    echo ""
    echo "=== Security Hardening ==="

    read -r -p "  Apply security hardening? (yes/no) [${SECURITY_HARDENING}]: " inp
    case "${inp:-$SECURITY_HARDENING}" in
        y|yes|Yes|YES) SECURITY_HARDENING="yes" ;;
        *)             SECURITY_HARDENING="no" ;;
    esac

    if [[ "$SECURITY_HARDENING" != "yes" ]]; then
        echo "  Security hardening disabled."
        return
    fi

    _yn_prompt() {
        local prompt="$1" varname="$2"
        local current="${!varname}"
        local inp
        read -r -p "  ${prompt} (yes/no) [${current}]: " inp
        case "${inp:-$current}" in
            y|yes|Yes|YES) printf -v "$varname" '%s' "yes" ;;
            *)             printf -v "$varname" '%s' "no" ;;
        esac
    }

    _yn_prompt "Enable fail2ban (brute-force protection)?"     SECURITY_FAIL2BAN
    _yn_prompt "Enable AppArmor (application confinement)?"    SECURITY_APPARMOR
    _yn_prompt "Enable auditd (system event logging)?"         SECURITY_AUDITD
    _yn_prompt "Enable AIDE (file integrity monitoring)?"      SECURITY_AIDE
    _yn_prompt "Enable automatic security updates?"            SECURITY_AUTO_UPDATES
}

apply_security_hardening() {
    if [[ "${SECURITY_HARDENING:-yes}" != "yes" ]]; then
        echo "Security hardening skipped."
        return
    fi

    echo "Applying security hardening..."

    # ── Packages ──────────────────────────────────────────────────────────────
    local pkgs="unattended-upgrades apt-listchanges rkhunter logwatch"
    [[ "${SECURITY_FAIL2BAN:-yes}"    == "yes" ]] && pkgs="$pkgs fail2ban"
    [[ "${SECURITY_APPARMOR:-yes}"    == "yes" ]] && pkgs="$pkgs apparmor apparmor-utils"
    [[ "${SECURITY_AUDITD:-yes}"      == "yes" ]] && pkgs="$pkgs auditd"
    [[ "${SECURITY_AIDE:-no}"         == "yes" ]] && pkgs="$pkgs aide"
    # shellcheck disable=SC2086
    DEBIAN_FRONTEND=noninteractive apt-get install -y $pkgs

    # ── Sysctl hardening ──────────────────────────────────────────────────────
    # NOTE: net.ipv4.ip_forward is kept at 1 so Docker/Podman container
    #       networking works. An explicit 0 here would silently break all
    #       container-to-internet traffic after reboot.
    cat > /etc/sysctl.d/99-hardening.conf << 'SYSCTL_EOF'
# Network security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
# Keep ip_forward=1 for container networking (Docker/Podman require it)
net.ipv4.ip_forward = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

# Memory protection
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 1
kernel.core_uses_pid = 1

# Filesystem
fs.suid_dumpable = 0
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
SYSCTL_EOF
    sysctl --system >/dev/null

    # ── File permissions ──────────────────────────────────────────────────────
    chmod 644 /etc/passwd /etc/group
    chmod 600 /etc/shadow /etc/gshadow
    chmod 644 /etc/passwd- /etc/group- 2>/dev/null || true
    chmod 600 /etc/shadow- /etc/gshadow- 2>/dev/null || true

    # ── Kernel module blacklist (conservative) ────────────────────────────────
    # squashfs is intentionally NOT blacklisted here — Docker overlay2 and
    # snap packages require it.
    cat > /etc/modprobe.d/blacklist-rare-network.conf << 'MODPROBE_EOF'
# Uncommon network protocols
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
# Uncommon filesystems
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install udf /bin/true
MODPROBE_EOF

    # ── User limits ───────────────────────────────────────────────────────────
    cat > /etc/security/limits.d/99-security.conf << 'LIMITS_EOF'
* hard nproc  2000
* hard nofile 65536
* soft nproc  1000
* soft nofile 8192
LIMITS_EOF

    # ── Password policies ─────────────────────────────────────────────────────
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/'  /etc/login.defs
    sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS 1/'   /etc/login.defs
    sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE 14/'  /etc/login.defs
    sed -i 's/^UMASK.*/UMASK 027/'                 /etc/login.defs

    # ── Fail2ban ──────────────────────────────────────────────────────────────
    if [[ "${SECURITY_FAIL2BAN:-yes}" == "yes" ]]; then
        # Use the SSH_PORT variable — not a hardcoded 22
        cat > /etc/fail2ban/jail.local << JAIL_EOF
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 3
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled  = true
port     = ${SSH_PORT}
filter   = sshd
logpath  = /var/log/auth.log
JAIL_EOF
        systemctl enable --now fail2ban
        systemctl restart fail2ban
        echo "  fail2ban configured for SSH port ${SSH_PORT}."
    fi

    # ── AppArmor ─────────────────────────────────────────────────────────────
    if [[ "${SECURITY_APPARMOR:-yes}" == "yes" ]]; then
        systemctl enable --now apparmor
        # Enforce profiles one at a time; skip failures so a broken profile
        # doesn't abort the entire hardening run.
        for profile in /etc/apparmor.d/*; do
            [[ -f "$profile" ]] || continue
            aa-enforce "$profile" 2>/dev/null || true
        done
        echo "  AppArmor enabled."
    fi

    # ── Auditd ────────────────────────────────────────────────────────────────
    if [[ "${SECURITY_AUDITD:-yes}" == "yes" ]]; then
        systemctl enable --now auditd
        cat >> /etc/audit/rules.d/audit.rules << 'AUDIT_EOF'
# Authentication
-w /var/log/auth.log -p wa -k auth_log
-w /etc/passwd       -p wa -k passwd_changes
-w /etc/shadow       -p wa -k shadow_changes
-w /etc/sudoers      -p wa -k sudoers_changes

# Time changes
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time_change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time_change
-a always,exit -F arch=b64 -S clock_settime -k time_change

# Network changes
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system_locale
AUDIT_EOF
        augenrules --load 2>/dev/null || true
        echo "  auditd configured."
    fi

    # ── AIDE (file integrity) ─────────────────────────────────────────────────
    if [[ "${SECURITY_AIDE:-no}" == "yes" ]]; then
        aide --init
        # AIDE 0.17+ compresses the database; handle both naming conventions
        if [[ -f /var/lib/aide/aide.db.new.gz ]]; then
            mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
        elif [[ -f /var/lib/aide/aide.db.new ]]; then
            mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
        fi

        cat > /etc/cron.daily/aide-check << 'CRON_EOF'
#!/bin/bash
/usr/bin/aide --check > /var/log/aide.log 2>&1 \
    || echo "AIDE detected changes — see /var/log/aide.log" \
       | mail -s "AIDE Alert $(hostname)" root 2>/dev/null || true
CRON_EOF
        chmod +x /etc/cron.daily/aide-check
        echo "  AIDE database initialized."
    fi

    # ── Unattended upgrades ───────────────────────────────────────────────────
    if [[ "${SECURITY_AUTO_UPDATES:-yes}" == "yes" ]]; then
        cat > /etc/apt/apt.conf.d/20auto-upgrades << 'APT_EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT_EOF
        systemctl enable --now unattended-upgrades
        echo "  Automatic security updates enabled."
    fi

    # ── Disable unnecessary services ──────────────────────────────────────────
    for svc in avahi-daemon.socket avahi-daemon.service; do
        systemctl disable "$svc" 2>/dev/null || true
        systemctl stop    "$svc" 2>/dev/null || true
    done

    echo "Security hardening applied."
}
