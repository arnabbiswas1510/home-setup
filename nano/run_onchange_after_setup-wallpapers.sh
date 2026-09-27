#!/usr/bin/env bash
# Enables freshbing (lockscreen Bing POTD) and daily-wallpaper (desktop IndianGods) timers.
# Managed by chezmoi - portable across Linux (systemd) and other environments.

if command -v systemctl >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; then
    systemctl --user daemon-reload
    systemctl --user enable --now freshbing.timer 2>/dev/null || true
    systemctl --user enable --now daily-wallpaper.timer 2>/dev/null || true
fi

# Run initial updates if in a graphical session
if [ -x "$HOME/.local/bin/freshbing" ]; then
    "$HOME/.local/bin/freshbing" >/dev/null 2>&1 || true
fi

if [ -x "$HOME/.local/bin/daily-wallpaper" ]; then
    "$HOME/.local/bin/daily-wallpaper" >/dev/null 2>&1 || true
fi
