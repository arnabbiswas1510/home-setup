#!/usr/bin/env bash
# Ensure Antigravity Link extension is installed if Antigravity IDE is present
# Managed by chezmoi - portable across Linux and macOS

if command -v antigravity-ide >/dev/null 2>&1; then
    if ! antigravity-ide --list-extensions 2>/dev/null | grep -qi "antigravity-link"; then
        antigravity-ide --install-extension cafeTechne.antigravity-link-extension >/dev/null 2>&1 || true
    fi
fi
