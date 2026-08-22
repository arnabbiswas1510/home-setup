#!/bin/bash
# =============================================================================
# Nano: Antigravity CLI (agy) Installer
# =============================================================================
set -euo pipefail

echo "1. Checking Antigravity CLI (agy)..."
if command -v agy >/dev/null 2>&1; then
    echo "Antigravity CLI (agy) is already installed at $(command -v agy)"
    agy --version || true
    exit 0
fi

echo "2. Installing Antigravity CLI (agy)..."
curl -fsSL https://antigravity.google/cli/install.sh | bash

# Ensure ~/.local/bin is in PATH for the current session
export PATH="$HOME/.local/bin:$PATH"

echo "Done! Antigravity CLI (agy) has been successfully installed."
echo "Run 'agy' to start using the Antigravity CLI."
