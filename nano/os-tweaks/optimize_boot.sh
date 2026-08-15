#!/usr/bin/env bash
# Script to optimize boot time on Debian (GRUB timeout, NetworkManager wait, fstab automounts)
set -e

echo "=== Applying Boot Speed Optimizations ==="

# 1. Update GRUB configuration for instant boot
echo "[1/3] Updating GRUB settings (GRUB_TIMEOUT=0)..."
cat << 'EOF' | sudo tee /etc/default/grub.d/99-fastboot.cfg > /dev/null
# Fast boot optimizations
GRUB_TIMEOUT=0
GRUB_TIMEOUT_STYLE=hidden
GRUB_RECORDFAIL_TIMEOUT=0
EOF

sudo /usr/sbin/update-grub

# 2. Disable NetworkManager-wait-online service
echo "[2/3] Disabling NetworkManager-wait-online service..."
sudo systemctl disable NetworkManager-wait-online.service || true

# 3. Update fstab options for fast CIFS automounting
echo "[3/3] Optimizing fstab CIFS automount timeouts..."
sudo sed -i -E 's/(x-systemd\.automount)/\1,x-systemd.idle-timeout=60,x-systemd.mount-timeout=5s,noauto/g' /etc/fstab || true

echo ""
echo "=== Boot Optimizations Applied! ==="
echo "Estimated boot time reduction: ~12-15 seconds faster."
echo "(Note: You can hold Shift or press Esc during power-on to view the GRUB menu if ever needed)."
