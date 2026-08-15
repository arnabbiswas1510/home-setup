#!/bin/bash
set -e

echo "1. Installing flatpak..."
apt-get update
apt-get install -y flatpak

echo "2. Adding Flathub repository..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

echo "3. Installing Plex Desktop..."
flatpak install -y flathub tv.plex.PlexDesktop

echo "Done! Plex Desktop has been successfully installed."
