#!/bin/bash

set -e

# Cleanup for previous execution
if [ -d /var/www/html/juice-shop ]; then
  sudo rm -rf /var/www/html/juice-shop
fi
if [ -d /usr/local/go ]; then
  sudo rm -rf /usr/local/go
fi
if [ -d /etc/caddy/ ]; then
  sudo rm -rf /etc/caddy/
fi
if [ -f /usr/local/bin/caddy ]; then
  sudo rm -f /usr/local/bin/caddy
fi
if [ -f /etc/systemd/system/juiceshop.service ]; then
  sudo rm -f /etc/systemd/system/juiceshop.service
fi
if [ -f /etc/systemd/system/caddy.service ]; then
  sudo rm -f /etc/systemd/system/caddy.service
fi
if [ -f ~/.bashrc.bak ]; then
  mv ~/.bashrc.bak ~/.bashrc
fi

# Cleanup done, now we can start installing

sudo apt update -y
sudo apt upgrade -y
sudo apt install libnotify-bin -y
sudo apt install git curl golang-go build-essential ca-certificates policycoreutils-python-utils -y

# Setting up the web portion
# Caddy + Coraza

sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/xcaddy/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-xcaddy-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/xcaddy/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-xcaddy.list
sudo apt update
sudo apt install xcaddy

xcaddy build --with github.com/corazawaf/coraza-caddy/v2
sudo mv caddy /usr/local/bin/caddy
sudo chmod +x /usr/local/bin/caddy
caddy version

sudo mkdir -p /etc/caddy/coraza
sudo mkdir -p /var/log/coraza
sudo mkdir -p /var/log/caddy
cd /etc/caddy/coraza
sudo git clone https://github.com/corazawaf/coraza-coreruleset.git
sudo git clone https://github.com/coreruleset/coreruleset.git crs
cd crs
sudo cp crs-setup.conf.example crs-setup.conf
sudo tee /etc/caddy/Caddyfile >/dev/null <<'EOF'
{
	order coraza_waf first
}
:80 {
	coraza_waf {
		load_owasp_crs
		directives `
			Include @coraza.conf-recommended
			Include @crs-setup.conf.example
			Include @owasp_crs/*.conf
			SecRuleEngine On
      SecAuditEngine On
      SecAuditLog /var/log/coraza/audit.log
      SecAuditLogType Serial
		`
	}
  log {
    output file /var/log/caddy/access.log
    level info
  }
	reverse_proxy 127.0.0.1:3000
}
EOF

curl https://raw.githubusercontent.com/nvm-sh/nvm/refs/heads/master/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
nvm install 24
nvm use 24

sudo mkdir -p /var/www/html/
sudo git clone https://github.com/juice-shop/juice-shop /var/www/html/juice-shop/
sudo chown ubuntu:ubuntu -R /var/www/html/juice-shop/
cd /var/www/html/juice-shop
npm install
sudo tee /etc/systemd/system/juiceshop.service >/dev/null <<EOF
[Unit]
Description=OWASP Juice Shop
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/var/www/html/juice-shop
Environment=PATH=${NVM_DIR}/versions/node/v24.22.3/bin:/usr/bin:/bin
ExecStart=${NVM_DIR}/versions/node/v24.22.3/bin/npm start
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/caddy.service >/dev/null <<'EOF'
[Unit]
Description=Caddy
After=network.target juiceshop.service

[Service]
User=root
ExecStart=/usr/local/bin/caddy run --config /etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable juiceshop caddy

# Setting up fail2ban and nftables
sudo apt install fail2ban -y
sudo rm /etc/fail2ban/jail.d/defaults-debian.conf
sudo tee /etc/fail2ban/jail.local >/dev/null <<EOF
[DEFAULT]
ignoreip = $(hostname -I | awk '{print $1}')
bantime = 30m
findtime = 10m
maxretry = 3
banaction=nftables-multiports
banaction_allports=nftables-multiports

[sshd]
enabled = true
filter = sshd
port = sshd
logpath = /var/log/auth.log
backend = systemd
EOF
sudo systemctl restart fail2ban

# Setting up auditctl
sudo apt install auditd audispd-plugins -y
sudo rm /etc/audit/rules.d/audit.rules
sudo tee /etc/audit/rules.d/00-audit.rules >/dev/null <<'EOF'
-b 8192
--backlog_wait_time 60000
-f 1
-e 1
-e 2
EOF

sudo tee /etc/audit/rules.d/30-fsys.rules >/dev/null <<'EOF'
-w /etc/passwd -p wa -k identity_changes
-w /etc/shadow -p rwax -k shadow_access
-w /etc/group -p wa -k identity_changes
-w /etc/gshadow -p wa -k identity_changes

-w /etc/hosts -p wa -k network_config
-w /etc/hostname -p wa -k network_config
-w /etc/resolv.conf -p wa -k network_config
-w /etc/netplan/ -p wa -k network_config
-w /etc/network/ -p wa -k network_config

-w /etc/ufw/ -p wa -k firewall
-w /etc/iptables/ -p wa -k firewall
-w /etc/nftables.conf -p wa -k firewall

-w /etc/systemd/ -p wa -k systemd
-w /lib/systemd/ -p wa -k systemd
-w /etc/crontab -p wa -k cron
-w /etc/cron.d/ -p wa -k cron
-w /etc/cron.hourly/ -p wa -k cron
-w /etc/cron.daily/ -p wa -k cron
-w /etc/cron.weekly/ -p wa -k cron
-w /etc/cron.monthly/ -p wa -k cron
-w /var/spool/cron/ -p wa -k cron

-w /etc/audit/auditd.conf -p wa -k audit_config
-w /etc/audit/rules.d/ -p wa -k audit_config
EOF

sudo tee /etc/audit/rules.d/40-syscalls.rules >/dev/null <<'EOF'
-a always,exit -F arch=b64 -S execve -k exec
-a always,exit -F arch=b32 -S execve -k exec
-a always,exit -F arch=b64 -S execve -F euid=0 -k exec
-a always,exit -F arch=b32 -S execve -F euid=0 -k exec

-a always,exit -F arch=b64 -S creat,open,openat,open_by_handle_at -F exit=-EACCES -k access_denied
-a always,exit -F arch=b64 -S creat,open,openat,open_by_handle_at -F exit=-EPERM -k access_denied
-a always,exit -F arch=b32 -S creat,open,openat,open_by_handle_at -F exit=-EACCES -k access_denied
-a always,exit -F arch=b32 -S creat,open,openat,open_by_handle_at -F exit=-EPERM -k access_denied
-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat,rmdir -F auid>=1000 -F auid!=4294967295 -k file_deletion
-a always,exit -F arch=b32 -S unlink,unlinkat,rename,renameat,rmdir -F auid>=1000 -F auid!=4294967295 -k file_deletion
-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=4294967295 -k permission_change
-a always,exit -F arch=b32 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=4294967295 -k permission_change
-a always,exit -F arch=b64 -S chown,fchown,fchownat,lchown -F auid>=1000 -F auid!=4294967295 -k ownership_change
-a always,exit -F arch=b32 -S chown,fchown,fchownat,lchown -F auid>=1000 -F auid!=4294967295 -k ownership_change

-a always,exit -F arch=b64 -S setuid,setgid,setreuid,setregid,setresuid,setresgid -k privilege_escalation
-a always,exit -F arch=b32 -S setuid,setgid,setreuid,setregid,setresuid,setresgid -k privilege_escalation
-a always,exit -F arch=b64 -S capset -k capability_change
-a always,exit -F arch=b32 -S capset -k capability_change

-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time_change
-a always,exit -F arch=b32 -S adjtimex,settimeofday,clock_settime -k time_change
-w /etc/localtime -p wa -k time_change

-a always,exit -F arch=b64 -S socket -F a0=2 -k network_socket_created  # IPv4
-a always,exit -F arch=b64 -S socket -F a0=10 -k network_socket_created # IPv6
-a always,exit -F arch=b32 -S socket -F a0=2 -k network_socket_created
-a always,exit -F arch=b32 -S socket -F a0=10 -k network_socket_created
-a always,exit -F arch=b64 -S connect -k network_connect
-a always,exit -F arch=b32 -S connect -k network_connect
EOF

sudo tee /etc/audit/rules.d/50-user-activity.rules >/dev/null <<'EOF'
-w /var/log/sudo.log -p wa -k sudo_log
-w /usr/bin/sudo -p x -k sudo_execution
-w /etc/login.defs -p wa -k login_config
-w /etc/securetty -p wa -k login_config
-w /etc/pam.d/ -p wa -k pam_config
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers

-w /usr/sbin/useradd -p x -k user_management
-w /usr/sbin/userdel -p x -k user_management
-w /usr/sbin/usermod -p x -k user_management
-w /usr/sbin/adduser -p x -k user_management

-w /usr/sbin/groupadd -p x -k group_management
-w /usr/sbin/groupdel -p x -k group_management
-w /usr/sbin/groupmod -p x -k group_management

-w /usr/bin/passwd -p x -k password_change
-w /usr/sbin/chpasswd -p x -k password_change

-w /usr/bin/su -p x -k su_execution
-w /etc/suauth -p wa -k su_config

-a always,exit -F arch=b64 -S open,openat -F path=/dev/tty -F auid>=1000 -F auid!=4294967295 -k terminal_access
-a always,exit -F arch=b32 -S open,openat -F path=/dev/tty -F auid>=1000 -F auid!=4294967295 -k terminal_access

-a always,exit -F arch=b64 -S open,openat -F dir=/dev/pts -F auid>=1000 -F auid!=4294967295 -k pts_access
-a always,exit -F arch=b32 -S open,openat -F dir=/dev/pts -F auid>=1000 -F auid!=4294967295 -k pts_access
EOF

sudo systemctl restart auditd

notify-send -i dialog-info "Automated setup completed" "System will restart in 15 seconds"

echo "=================================================="
echo "Automated setup completed."
echo "System will restart in 15 seconds"
echo "=================================================="
sleep 15
reboot
