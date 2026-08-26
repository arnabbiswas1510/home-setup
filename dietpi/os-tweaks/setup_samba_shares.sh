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
   server string = Samba Server
   security = user
   map to guest = Never

   # Compatibility with modern Windows / clients
   server min protocol = SMB2
   server max protocol = SMB3

   # Disable printing
   load printers = no
   disable spoolss = yes
   printing = bsd
   printcap name = /dev/null

#============================ Share Definitions ==============================

[pom]
   comment = Pom Home Directory
   path = /home/pom
   read only = no
   browsable = yes
   valid users = pom
   create mask = 0664
   directory mask = 0775

[books]
   comment = Books Library
   path = /mnt/books
   read only = no
   browsable = yes
   valid users = pom
   create mask = 0664
   directory mask = 0775

[media1]
   comment = Media 1
   path = /mnt/media1
   read only = no
   browsable = yes
   valid users = pom
   create mask = 0664
   directory mask = 0775

[media2]
   comment = Media 2
   path = /mnt/media2
   read only = no
   browsable = yes
   valid users = pom
   create mask = 0664
   directory mask = 0775

[photos]
   comment = Photos
   path = /mnt/photos
   read only = no
   browsable = yes
   valid users = pom
   create mask = 0664
   directory mask = 0775

[tvShows]
   comment = TV Shows
   path = /mnt/tvShows
   read only = no
   browsable = yes
   valid users = pom
   create mask = 0664
   directory mask = 0775

[scratch]
   comment = Scratch Storage
   path = /mnt/scratch
   read only = no
   browsable = yes
   valid users = pom
   create mask = 0664
   directory mask = 0775
EOF

echo "[3/4] Ensuring export directories exist with appropriate permissions..."
sudo mkdir -p /mnt/media1 /mnt/media2 /mnt/tvShows /mnt/books /mnt/scratch /mnt/photos /mnt/backup

echo "[4/4] Restarting Samba services..."
sudo systemctl restart smbd nmbd

echo ""
echo "=== Samba Shares Configured Successfully! ==="
echo "Make sure to set Samba password for the pom user if not already configured:"
echo "  sudo smbpasswd -a pom"
