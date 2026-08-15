#!/bin/sh
set -e

LOG_DIR="/var/log"
mkdir -p "$LOG_DIR"

# Ensure mounts exist
mountpoint -q /mnt/scratch || exit 0
mountpoint -q /mnt/photos || exit 0

rsync_copy() {
    SRC="$1"
    DEST="$2"
    NAME="$3"
    LOG="$LOG_DIR/$NAME.log"

    echo "$(date) - Starting $SRC -> $DEST" >> "$LOG"

    rsync -ruvh \
      --info=progress2 \
      "$SRC"/ "$DEST"/ >> "$LOG" 2>&1

    echo "$(date) - Finished with status $?" >> "$LOG"
}

rsync_copy "/mnt/scratch" "/mnt/photos" "photos"

