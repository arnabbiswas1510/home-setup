#!/usr/bin/env bash
# =============================================================================
# DietPi: Antigravity CLI (agy) Standalone Installer
# =============================================================================
set -euo pipefail

echo "=== Installing Antigravity CLI (agy) on DietPi ==="

if command -v agy >/dev/null 2>&1; then
    echo "--> Antigravity CLI (agy) is already installed at: $(command -v agy)"
    agy --version || true
    exit 0
fi

# Run official Antigravity CLI installer
echo "--> Running official Antigravity CLI installer..."
curl -fsSL https://antigravity.google/cli/install.sh | bash

# Ensure ~/.local/bin is in PATH for the current session
export PATH="$HOME/.local/bin:$PATH"

echo ""
echo "=== Antigravity CLI (agy) installation complete! ==="
echo "Run 'agy' to get started."
