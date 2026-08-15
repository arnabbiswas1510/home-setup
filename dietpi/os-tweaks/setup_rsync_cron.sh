#!/usr/bin/env bash
# =============================================================================
# DietPi Rsync Periodic Sync Cron Setup
# Schedules run-all-rsync.sh (e.g. scratch -> photos backup)
# =============================================================================
set -euo pipefail

echo "=== Configuring Periodic Rsync Job on DietPi ==="

RSYNC_BIN="/home/dietpi/bin/run-all-rsync.sh"
CRON_JOB="0 */2 * * * $RSYNC_BIN >/dev/null 2>&1"

# Ensure user bin script is executable
if [ -f "$RSYNC_BIN" ]; then
    chmod +x "$RSYNC_BIN"
fi

# Add to crontab if not already present
( crontab -l 2>/dev/null | grep -v -F "$RSYNC_BIN" ; echo "$CRON_JOB" ) | crontab -

echo "Cron job scheduled: runs $RSYNC_BIN every 2 hours."
