#!/bin/bash
set -e

echo "1. Installing Syncthing..."
sudo apt-get update
sudo apt-get install -y syncthing

echo "2. Enabling Syncthing user service..."
systemctl --user enable --now syncthing.service || true

echo "Done! Syncthing has been installed."
echo "You can access the Syncthing Web UI in your browser at: http://127.0.0.1:8384"
