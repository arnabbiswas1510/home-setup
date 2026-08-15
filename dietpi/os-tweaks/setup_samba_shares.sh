#!/usr/bin/env bash
# =============================================================================
# DietPi Samba Server Configuration Script
# Configures Samba exports for media, books, tvShows, scratch, and home dirs
# =============================================================================
set -euo pipefail

echo "=== Configuring Samba Shares for DietPi NAS ==="

SMB_CONF="/etc/samba/smb.conf"
SMB_BAK="/etc/samba/smb.conf.bak.$(date +%s)"

echo "[1/4] Backing up existing smb.conf to $SMB_BAK..."
if [ -f "$SMB_CONF" ]; then
  sudo cp "$SMB_CONF" "$SMB_BAK"
fi

echo "[2/4] Writing optimized Samba configuration..."
cat << 'EOF' | sudo tee "$SMB_CONF" > /dev/null
[global]
   workgroup = WORKGROUP
   server string = DietPi NAS Server
   security = user
   map to guest = Bad User
   dns proxy = no
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file
   panic action = /usr/share/samba/panic-action %d
   server role = standalone server
   obey pam restrictions = yes
   unix password sync = yes
   passwd program = /usr/bin/passwd %u
   passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
   pam password change = yes
   usershare allow guests = yes
   
   # Performance Tweaks
   min receivefile size = 16384
   use sendfile = yes
   aio read size = 16384
   aio write size = 16384
   socket options = TCP_NODELAY IPTOS_LOWDELAY

[dietpi]
   path = /home/dietpi
   read only = no
   browsable = yes
   writable = yes
   guest ok = no
   create mask = 0775
   directory mask = 0775
   valid users = dietpi pom root

[dietpi-home]
   path = /home/dietpi
   read only = no
   browsable = yes
   writable = yes
   guest ok = no
   create mask = 0775
   directory mask = 0775
   valid users = dietpi pom root

[books]
   path = /mnt/books
   read only = no
   browsable = yes
   writable = yes
   guest ok = no
   create mask = 0775
   directory mask = 0775
   valid users = dietpi pom root

[media1]
   path = /mnt/media1
   read only = no
   browsable = yes
   writable = yes
   guest ok = no
   create mask = 0775
   directory mask = 0775
   valid users = dietpi pom root

[media2]
   path = /mnt/media2
   read only = no
   browsable = yes
   writable = yes
   guest ok = no
   create mask = 0775
   directory mask = 0775
   valid users = dietpi pom root

[tvShows]
   path = /mnt/tvShows
   read only = no
   browsable = yes
   writable = yes
   guest ok = no
   create mask = 0775
   directory mask = 0775
   valid users = dietpi pom root

[scratch]
   path = /mnt/scratch
   read only = no
   browsable = yes
   writable = yes
   guest ok = no
   create mask = 0775
   directory mask = 0775
   valid users = dietpi pom root

[root]
   path = /
   read only = no
   browsable = yes
   writable = yes
   guest ok = no
   create mask = 0775
   directory mask = 0775
   valid users = root dietpi pom
EOF

echo "[3/4] Ensuring export directories exist with appropriate permissions..."
sudo mkdir -p /mnt/media1 /mnt/media2 /mnt/tvShows /mnt/books /mnt/scratch /mnt/photos

echo "[4/4] Restarting Samba services..."
sudo systemctl restart smbd nmbd

echo ""
echo "=== Samba Shares Configured Successfully! ==="
echo "Make sure to set Samba password for the dietpi user if not already configured:"
echo "  sudo smbpasswd -a dietpi"
