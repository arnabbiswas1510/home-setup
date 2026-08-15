#!/usr/bin/env bash
# =============================================================================
# DietPi Gitwatch Service Deployment Script
# Automatically watches Git repositories and commits/pushes changes
# =============================================================================
set -euo pipefail

echo "=== Setting up Gitwatch on DietPi ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITWATCH_DIR="$(cd "$SCRIPT_DIR/../gitwatch" && pwd)"

echo "[1/4] Installing inotify-tools dependency..."
sudo apt-get update -qq
sudo apt-get install -y inotify-tools git

echo "[2/4] Installing gitwatch executable to /usr/local/bin..."
sudo cp "$GITWATCH_DIR/gitwatch.sh" /usr/local/bin/gitwatch
sudo chmod +x /usr/local/bin/gitwatch

echo "[3/4] Installing systemd unit template gitwatch@.service..."
sudo cp "$GITWATCH_DIR/gitwatch@.service" /etc/systemd/system/gitwatch@.service
sudo systemctl daemon-reload

echo "[4/4] Setup complete!"
echo ""
echo "To enable auto-sync for a folder (e.g. /home/dietpi/obsidian):"
echo "  sudo systemctl enable --now gitwatch@$(systemd-escape /home/dietpi/obsidian).service"
