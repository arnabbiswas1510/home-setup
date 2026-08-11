#!/bin/bash
# Clean Cache Script for User Applications

# 1. ZapZap WhatsApp Client Cache
ZAPZAP_CACHE="$HOME/.var/app/com.rtosta.zapzap/cache/ZapZap/QtWebEngine/storage-whats/Cache"
if [ -d "$ZAPZAP_CACHE" ]; then
    rm -rf "$ZAPZAP_CACHE"/*
    echo "[$(date)] Cleared ZapZap cache."
fi

# 2. Jellyfin Desktop Cache
JELLYFIN_CACHE="$HOME/.var/app/org.jellyfin.JellyfinDesktop/cache"
if [ -d "$JELLYFIN_CACHE" ]; then
    rm -rf "$JELLYFIN_CACHE"/*
    echo "[$(date)] Cleared Jellyfin Desktop cache."
fi

# 3. Old Thumbnail Cache (files older than 7 days)
if [ -d "$HOME/.cache/thumbnails" ]; then
    find "$HOME/.cache/thumbnails" -type f -mtime +7 -delete
    echo "[$(date)] Cleared old desktop thumbnails."
fi

# 4. Old WebEngine/Electron Shader Caches (older than 14 days)
find "$HOME/.cache" -name "*shadercache*" -type f -mtime +14 -delete 2>/dev/null

echo "[$(date)] Cache cleanup completed successfully."
