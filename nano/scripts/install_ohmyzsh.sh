#!/bin/bash
set -e

echo "1. Installing Zsh..."
sudo apt-get update
sudo apt-get install -y zsh

echo "2. Installing Oh My Zsh..."
if [ -d "$HOME/.oh-my-zsh" ]; then
    echo "Oh My Zsh is already installed in $HOME/.oh-my-zsh"
else
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

echo "3. Changing default shell to Zsh..."
sudo chsh -s "$(which zsh)" "$USER"

# Ensure ~/.local/bin is in PATH for Zsh
if [ -f "$HOME/.zshrc" ] && ! grep -q '\.local/bin' "$HOME/.zshrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
fi

echo "Done! Oh My Zsh has been installed and set as your default shell."
echo "Log out and log back in (or run 'zsh') to start using Oh My Zsh."
