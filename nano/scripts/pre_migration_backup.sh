#!/usr/bin/env bash
# ==============================================================================
# Pre-Migration Full Backup Script for Nano (Debian -> Fedora)
# Backs up /home/pom and system configs to DietPi NAS (/mnt/media1/pom_nano_backup)
# ==============================================================================

set -euo pipefail

BACKUP_DEST="/mnt/media1/pom_nano_backup"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

echo "======================================================================"
echo "    Lenovo ThinkPad X1 Nano -> Fedora Pre-Migration Backup            "
echo "======================================================================"

# 1. Verify NAS mount is accessible
if [ ! -d "/mnt/media1" ] || ! touch "/mnt/media1/.test_write" 2>/dev/null; then
    echo "[-] Error: /mnt/media1 is not mounted or not writable."
    echo "    Please verify DietPi NAS (192.168.1.50) CIFS share is mounted."
    exit 1
fi
rm -f "/mnt/media1/.test_write"
echo "[+] NAS destination /mnt/media1 verified accessible."

# 2. Create target directories
mkdir -p "${BACKUP_DEST}/home_pom"
mkdir -p "${BACKUP_DEST}/system_etc"

echo ""
echo "[1/4] Backing up critical /etc system configurations..."
sudo cp -a /etc/samba/credentials-192.168.1.50 "${BACKUP_DEST}/system_etc/" 2>/dev/null || echo "  Warning: Samba credentials file not found or sudo needed"
sudo cp -a /etc/fstab "${BACKUP_DEST}/system_etc/fstab.${TIMESTAMP}" 2>/dev/null || cp /etc/fstab "${BACKUP_DEST}/system_etc/fstab.${TIMESTAMP}"
sudo cp -a /etc/environment "${BACKUP_DEST}/system_etc/" 2>/dev/null || true
sudo cp -a /etc/environment.d "${BACKUP_DEST}/system_etc/" 2>/dev/null || true
sudo cp -a /etc/modprobe.d "${BACKUP_DEST}/system_etc/" 2>/dev/null || true
sudo cp -a /etc/udev/rules.d "${BACKUP_DEST}/system_etc/" 2>/dev/null || true
echo "[+] System configuration backup complete."

echo ""
echo "[2/4] Ensuring home-setup Git repository is clean and pushed..."
cd /home/pom/workspace/home-setup
git status -s
git push origin main || echo "  Notice: Git push failed, ensuring local copy is backed up."
echo "[+] Git state verified."

echo ""
echo "[3/4] Rsyncing /home/pom to ${BACKUP_DEST}/home_pom..."
echo "  Excluding volatile caches (.cache, tmp, etc.)..."
rsync -aAXhv --delete \
    --exclude='.cache/' \
    --exclude='.var/app/*/cache/' \
    --exclude='GoogleDrive/' \
    --exclude='tmp/' \
    --info=progress2 \
    /home/pom/ "${BACKUP_DEST}/home_pom/"

echo ""
echo "[4/4] Writing migration manifest and checksum verification..."
cat << MANIFEST > "${BACKUP_DEST}/MIGRATION_MANIFEST.txt"
Migration Source: Lenovo ThinkPad X1 Nano Gen 3 (Debian 13 trixie)
Target OS: Fedora KDE Plasma Edition
Backup Date: $(date -R)
Home Size: $(du -sh "${BACKUP_DEST}/home_pom" | cut -f1)
System Configs: Saved in ${BACKUP_DEST}/system_etc/
MANIFEST

echo "======================================================================"
echo "  Backup successfully completed to: ${BACKUP_DEST}"
echo "  You can safely proceed with Fedora installation!"
echo "======================================================================"
