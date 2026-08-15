#!/usr/bin/env bash
# =============================================================================
# DietPi Headless Server: Initial System Setup & Package Provisioning
# =============================================================================
set -euo pipefail

echo "=== [1/5] Updating APT and installing core server tools ==="
sudo apt-get update
sudo apt-get install -y \
  curl \
  wget \
  git \
  zsh \
  lsof \
  rclone \
  rsync \
  samba \
  cifs-utils \
  inotify-tools \
  ca-certificates \
  gnupg \
  lsb-release \
  apt-transport-https

echo "=== [2/5] Installing Docker and Docker Compose ==="
if ! command -v docker >/dev/null 2>&1; then
  echo "--> Setting up Docker official APT repository..."
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

echo "--> Ensuring docker group membership for $USER..."
sudo usermod -aG docker "$USER" || true

echo "=== [3/5] Installing and Configuring Tailscale ==="
if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
sudo systemctl enable --now tailscaled

echo "=== [4/5] Enabling Core System Services ==="
sudo systemctl enable --now docker
sudo systemctl enable --now smbd nmbd

echo "=== [5/5] Creating Standard Storage Directories ==="
sudo mkdir -p /mnt/media1 /mnt/media2 /mnt/tvShows /mnt/books /mnt/scratch /mnt/photos
sudo chown -R 1000:1000 /mnt/media1 /mnt/media2 /mnt/tvShows /mnt/books /mnt/scratch /mnt/photos || true

echo ""
echo "=== DietPi System Setup Complete! ==="
echo "Run setup_samba_shares.sh next to configure NAS share access."
