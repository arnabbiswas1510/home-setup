#!/bin/bash
# =============================================================================
# DietPi: Zsh & Oh My Zsh Unattended Installer
# =============================================================================
set -euo pipefail

echo "=== [1/3] Installing Zsh ==="
sudo apt-get update
sudo apt-get install -y zsh

echo "=== [2/3] Installing Oh My Zsh ==="
if [ -d "$HOME/.oh-my-zsh" ]; then
    echo "--> Oh My Zsh is already installed in $HOME/.oh-my-zsh"
else
    echo "--> Running Oh My Zsh installer..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

echo "=== [3/3] Setting Default Shell & PATH ==="
sudo chsh -s "$(which zsh)" "$USER"

# Ensure ~/.local/bin and ~/bin are in PATH for Zsh
if [ -f "$HOME/.zshrc" ]; then
    if ! grep -q '\.local/bin' "$HOME/.zshrc"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    fi
    if ! grep -q 'HOME/bin' "$HOME/.zshrc"; then
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
    fi
fi

echo ""
echo "=== Oh My Zsh installation complete! ==="
echo "To switch to Zsh immediately in this session, run:"
echo "  zsh"
echo "Or log out and log back in for the new default shell to take effect."
