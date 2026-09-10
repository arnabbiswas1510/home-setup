#!/usr/bin/env bash
# =============================================================================
# DietPi: Antigravity CLI (agy) Standalone Installer
# =============================================================================
set -euo pipefail

echo "=== Installing Antigravity CLI (agy) on DietPi ==="

LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

if ! command -v agy >/dev/null 2>&1 && [ ! -f "$LOCAL_BIN/agy" ]; then
    echo "--> Running official Antigravity CLI installer..."
    curl -fsSL https://antigravity.google/cli/install.sh | bash
else
    echo "--> Antigravity CLI binary found at $LOCAL_BIN/agy"
fi

# Ensure ~/.local/bin is permanently added to all shell configuration files
for rc_file in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
    if [ -f "$rc_file" ]; then
        if ! grep -q '\.local/bin' "$rc_file"; then
            echo "--> Adding ~/.local/bin to PATH in $rc_file..."
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc_file"
        fi
    fi
done

echo ""
echo "=== Antigravity CLI (agy) setup complete! ==="
echo "To use 'agy' in your current shell session, run:"
echo "  source ~/.zshrc    # (if using Zsh)"
echo "  source ~/.bashrc   # (if using Bash)"
