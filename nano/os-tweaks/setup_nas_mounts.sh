#!/bin/bash
set -e

echo "1. Installing cifs-utils..."
apt-get update
apt-get install -y cifs-utils

echo "2. Creating mount directories..."
mkdir -p /etc/samba
mkdir -p /mnt/dietpi /mnt/dietpi-home /mnt/books /mnt/media1 /mnt/media2 /mnt/tvShows /mnt/scratch

echo "3. Writing Samba credentials..."
cat << 'EOF' > /etc/samba/credentials-192.168.1.50
username=dietpi
password=paro
domain=WORKGROUP
EOF
chmod 600 /etc/samba/credentials-192.168.1.50

echo "4. Removing any previous NAS entries in /etc/fstab..."
sed -i '/192.168.1.50/d' /etc/fstab

echo "5. Adding mount entries to /etc/fstab..."
cat << 'EOF' >> /etc/fstab

# NAS 192.168.1.50 Samba Shares
//192.168.1.50/dietpi      /mnt/dietpi      cifs credentials=/etc/samba/credentials-192.168.1.50,uid=1000,gid=1000,iocharset=utf8,nofail,_netdev,x-systemd.automount,x-systemd.idle-timeout=60,x-systemd.mount-timeout=5s,noauto 0 0
//192.168.1.50/dietpi-home /mnt/dietpi-home cifs credentials=/etc/samba/credentials-192.168.1.50,uid=1000,gid=1000,iocharset=utf8,nofail,_netdev,x-systemd.automount,x-systemd.idle-timeout=60,x-systemd.mount-timeout=5s,noauto 0 0
//192.168.1.50/books       /mnt/books       cifs credentials=/etc/samba/credentials-192.168.1.50,uid=1000,gid=1000,iocharset=utf8,nofail,_netdev,x-systemd.automount,x-systemd.idle-timeout=60,x-systemd.mount-timeout=5s,noauto 0 0
//192.168.1.50/media1      /mnt/media1      cifs credentials=/etc/samba/credentials-192.168.1.50,uid=1000,gid=1000,iocharset=utf8,nofail,_netdev,x-systemd.automount,x-systemd.idle-timeout=60,x-systemd.mount-timeout=5s,noauto 0 0
//192.168.1.50/media2      /mnt/media2      cifs credentials=/etc/samba/credentials-192.168.1.50,uid=1000,gid=1000,iocharset=utf8,nofail,_netdev,x-systemd.automount,x-systemd.idle-timeout=60,x-systemd.mount-timeout=5s,noauto 0 0
//192.168.1.50/tvShows     /mnt/tvShows     cifs credentials=/etc/samba/credentials-192.168.1.50,uid=1000,gid=1000,iocharset=utf8,nofail,_netdev,x-systemd.automount,x-systemd.idle-timeout=60,x-systemd.mount-timeout=5s,noauto 0 0
//192.168.1.50/scratch     /mnt/scratch     cifs credentials=/etc/samba/credentials-192.168.1.50,uid=1000,gid=1000,iocharset=utf8,nofail,_netdev,x-systemd.automount,x-systemd.idle-timeout=60,x-systemd.mount-timeout=5s,noauto 0 0
//192.168.1.50/root        /mnt/dietpi-root cifs credentials=/etc/samba/credentials-192.168.1.50,uid=1000,gid=1000,iocharset=utf8,nofail,_netdev,x-systemd.automount,x-systemd.idle-timeout=60,x-systemd.mount-timeout=5s,noauto 0 0
EOF

echo "6. Mounting all shares..."
systemctl daemon-reload
mount -a

echo "Done! All NAS shares are mounted under /mnt."
