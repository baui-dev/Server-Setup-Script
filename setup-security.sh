#!/bin/bash
# Server Security Hardening Script
# This script applies security best practices for Debian servers

set -euo pipefail

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Update system and install security packages
apt update && apt upgrade -y
apt install -y iptables-persistent fail2ban unattended-upgrades apt-listchanges \
    ufw lynis rkhunter chkrootkit aide logwatch psad clamav clamav-daemon \
    apparmor apparmor-utils auditd

# Harden SSH configuration
SSH_CONFIG="/etc/ssh/sshd_config"
cp "$SSH_CONFIG" "${SSH_CONFIG}.bak"
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSH_CONFIG"
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSH_CONFIG"
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSH_CONFIG"
sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' "$SSH_CONFIG"
sed -i 's/^#*AllowTcpForwarding.*/AllowTcpForwarding no/' "$SSH_CONFIG"
sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' "$SSH_CONFIG"
sed -i 's/^#*ClientAliveInterval.*/ClientAliveInterval 300/' "$SSH_CONFIG"
sed -i 's/^#*ClientAliveCountMax.*/ClientAliveCountMax 2/' "$SSH_CONFIG"
sed -i 's/^#*Protocol.*/Protocol 2/' "$SSH_CONFIG"
echo "AllowGroups sudo" >> "$SSH_CONFIG"

# Restart SSH
systemctl restart ssh

# Set up firewall (iptables)
iptables -F
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT # SSH
iptables -A INPUT -p tcp --dport 80 -j ACCEPT # HTTP
iptables -A INPUT -p tcp --dport 443 -j ACCEPT # HTTPS
iptables-save > /etc/iptables/rules.v4

# Harden sysctl settings
cat <<EOF >/etc/sysctl.d/99-hardening.conf
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
net.ipv4.ip_forward = 0
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

# Process restrictions
fs.suid_dumpable = 0
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
EOF
sysctl --system

# Configure fail2ban
systemctl enable fail2ban
systemctl start fail2ban

# Create custom fail2ban jail for SSH
cat <<EOF >/etc/fail2ban/jail.local
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
ignoreip = 127.0.0.1/8 ::1
EOF
systemctl restart fail2ban

# Disable unnecessary kernel modules
cat <<EOF >/etc/modprobe.d/blacklist-rare-network.conf
# Disable rare network protocols
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
# Disable uncommon filesystems
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install udf /bin/true
# Disable USB storage if not needed
# install usb-storage /bin/true
EOF

# Set strict file permissions
chmod 644 /etc/passwd
chmod 644 /etc/group
chmod 600 /etc/shadow
chmod 600 /etc/gshadow
chmod 644 /etc/passwd-
chmod 644 /etc/group-
chmod 600 /etc/shadow-
chmod 600 /etc/gshadow-

# Configure user limits
cat <<EOF >/etc/security/limits.d/99-security.conf
# Hard limit for max processes per user
* hard nproc 1000
# Hard limit for max open files
* hard nofile 65536
# Soft limits
* soft nproc 500
* soft nofile 1024
EOF

# Configure login.defs for password policies
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 90/' /etc/login.defs
sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS 7/' /etc/login.defs
sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE 14/' /etc/login.defs
sed -i 's/^UMASK.*/UMASK 027/' /etc/login.defs

# Enable AppArmor
systemctl enable apparmor
systemctl start apparmor
aa-enforce /etc/apparmor.d/*

# Configure auditd for logging
systemctl enable auditd
systemctl start auditd

# Add audit rules
cat <<EOF >>/etc/audit/rules.d/audit.rules
# Monitor authentication events
-w /var/log/auth.log -p wa -k auth_log
-w /etc/passwd -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/sudoers -p wa -k sudoers_changes

# Monitor system calls
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time_change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time_change
-a always,exit -F arch=b64 -S clock_settime -k time_change
-a always,exit -F arch=b32 -S clock_settime -k time_change

# Monitor network changes
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system_locale
-a always,exit -F arch=b32 -S sethostname -S setdomainname -k system_locale
EOF

# Initialize AIDE database
aide --init
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Configure automatic AIDE checks
cat <<EOF >/etc/cron.daily/aide-check
#!/bin/bash
/usr/bin/aide --check > /var/log/aide.log 2>&1
if [ \$? -ne 0 ]; then
    echo "AIDE detected changes - check /var/log/aide.log" | mail -s "AIDE Alert" root
fi
EOF
chmod +x /etc/cron.daily/aide-check

# Enable automatic security updates
sed -i 's/^//g' /etc/apt/apt.conf.d/20auto-upgrades
cat <<EOF >/etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
systemctl enable unattended-upgrades
systemctl start unattended-upgrades

# Disable unused services
systemctl disable avahi-daemon.socket avahi-daemon.service 2>/dev/null || true
systemctl stop avahi-daemon.socket avahi-daemon.service 2>/dev/null || true

# Print summary
echo "Security hardening complete. SSH, firewall, fail2ban, sysctl, and auto-updates configured."
echo "Additional security features enabled:"
echo "- AppArmor for application confinement"
echo "- Auditd for system event logging"
echo "- AIDE for file integrity monitoring"
echo "- Disabled unnecessary kernel modules"
echo "- Strict file permissions"
echo "- User process limits"
echo "- Password policy enforcement"
