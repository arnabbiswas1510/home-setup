#!/usr/bin/env bash
# Script to configure high-performance ZRAM compressed swap on Debian
set -e

echo "=== Setting up ZRAM Compressed Swap ==="

# 1. Install zram-tools
echo "[1/3] Installing zram-tools..."
sudo apt-get update -qq
sudo apt-get install -y zram-tools

# 2. Configure zramswap for zstd and 50% RAM allocation
echo "[2/3] Writing /etc/default/zramswap configuration..."
cat << 'CONFIG' | sudo tee /etc/default/zramswap > /dev/null
# Compression algorithm selection
ALGO=zstd

# Specifies the amount of RAM allocated as zram swap (in percent of total RAM)
PERCENT=50

# Priority of zram swap device
PRIORITY=100
CONFIG

# 3. Enable and start zramswap service
echo "[3/3] Enabling and starting zramswap.service..."
sudo systemctl enable --now zramswap.service
sudo systemctl restart zramswap.service

echo ""
echo "=== ZRAM Swap Enabled Successfully! ==="
echo "Active swap devices:"
swapon --show || cat /proc/swaps
echo ""
echo "Memory overview:"
free -h
