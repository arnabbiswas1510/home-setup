#!/usr/bin/env bash
# daily-user-update.sh - Automated updater for user tools, flatpaks, and CLI binaries
set -u

LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/auto-update"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/update-$(date +%Y%m%d).log"
LOCK_FILE="/tmp/daily-user-update-${UID}.lock"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

# 0. Concurrency guard
if [ -e "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE" 2>/dev/null || true)
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        log "Another update process ($PID) is already running. Exiting."
        exit 0
    fi
fi
echo "$$" > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

log "=== Starting daily user-level software update ==="

# 1. Network connectivity pre-check (3-second timeout)
if ! curl -s --connect-timeout 3 -I https://cloudflare.com >/dev/null 2>&1; then
    log "Network unreachable. Skipping scheduled update."
    exit 0
fi

ERRORS=0
FAILED_COMPONENTS=()

record_failure() {
    local component="$1"
    ERRORS=$((ERRORS + 1))
    FAILED_COMPONENTS+=("$component")
    log "Warning: $component update failed or reported errors."
}

# 2. Update Flatpak applications & runtimes
if command -v flatpak >/dev/null 2>&1; then
    log "Updating Flatpaks..."
    if ! flatpak update --noninteractive -y >> "$LOG_FILE" 2>&1; then
        record_failure "Flatpaks"
    fi
    flatpak uninstall --unused --noninteractive -y >> "$LOG_FILE" 2>&1 || true
fi

# 3. Update uv & uv-managed global tools
if command -v uv >/dev/null 2>&1; then
    log "Updating uv..."
    uv self update >> "$LOG_FILE" 2>&1 || record_failure "uv"

    log "Updating uv tools (graphify, cmake, etc.)..."
    uv tool upgrade --all >> "$LOG_FILE" 2>&1 || record_failure "uv-tools"
fi

# 4. Update yt-dlp
if command -v yt-dlp >/dev/null 2>&1; then
    log "Updating yt-dlp..."
    yt-dlp -U >> "$LOG_FILE" 2>&1 || record_failure "yt-dlp"
fi

# 5. Update chezmoi
if command -v chezmoi >/dev/null 2>&1; then
    log "Updating chezmoi..."
    chezmoi upgrade --force >> "$LOG_FILE" 2>&1 || record_failure "chezmoi"
fi

# 6. Update deno
if [ -x "$HOME/.deno/bin/deno" ]; then
    log "Updating deno..."
    "$HOME/.deno/bin/deno" upgrade --quiet >> "$LOG_FILE" 2>&1 || record_failure "deno"
fi

# 7. Update audible-cli venv
if [ -x "$HOME/.local/share/audible-cli/bin/pip" ]; then
    log "Updating audible-cli..."
    "$HOME/.local/share/audible-cli/bin/pip" install --upgrade audible-cli --quiet >> "$LOG_FILE" 2>&1 || record_failure "audible-cli"
fi

# 8. Helper: Update app extracted from a GitHub release .deb package
update_github_deb_app() {
    local name="$1"
    local repo="$2"
    local deb_pattern="$3"
    local subpath="$4"
    local target_dir="$5"
    shift 5
    local binaries=("$@")

    if [ ! -d "$target_dir" ]; then
        return 0
    fi

    log "Checking for $name updates..."
    local current_version=""
    if [ -f "$target_dir/version.txt" ]; then
        current_version=$(cat "$target_dir/version.txt" 2>/dev/null || true)
    fi

    local latest_json
    latest_json=$(curl -sL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null || true)
    local latest_tag
    latest_tag=$(echo "$latest_json" | grep '"tag_name":' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')

    if [ -n "$latest_tag" ] && [ "$latest_tag" != "$current_version" ]; then
        log "Updating $name from ${current_version:-unknown} to $latest_tag..."
        local deb_url
        deb_url=$(echo "$latest_json" | grep -E "\"browser_download_url\":.*$deb_pattern" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')
        if [ -n "$deb_url" ]; then
            local tmp_dir
            tmp_dir=$(mktemp -d)
            if curl -sL -o "$tmp_dir/pkg.deb" "$deb_url" >> "$LOG_FILE" 2>&1; then
                dpkg-deb -x "$tmp_dir/pkg.deb" "$tmp_dir/extracted" >> "$LOG_FILE" 2>&1
                if [ -d "$tmp_dir/extracted/$subpath" ]; then
                    cp -rf "$tmp_dir/extracted/$subpath/"* "$target_dir/"
                    if [ ${#binaries[@]} -gt 0 ]; then
                        for bin in "${binaries[@]}"; do
                            chmod +x "$target_dir/$bin" 2>/dev/null || true
                        done
                    fi
                    echo "$latest_tag" > "$target_dir/version.txt"
                    log "$name successfully updated to $latest_tag"
                fi
            else
                record_failure "$name"
            fi
            rm -rf "$tmp_dir"
        else
            record_failure "$name (download URL not found)"
        fi
    else
        log "$name is up to date (${latest_tag:-$current_version})"
    fi
}

# 9. Update GitHub-installed applications
update_github_deb_app "Libation" "rmcrackan/Libation" "linux-chardonnay-amd64\.deb" "usr/lib/libation" "$HOME/.local/lib/libation" "Libation" "LibationCli" "Hangover"
update_github_deb_app "IPTVnator" "4gray/iptvnator" "linux-amd64\.deb" "opt/IPTVnator" "$HOME/.local/lib/iptvnator" "iptvnator" "iptvnator.bin"

# 10. Prune logs older than 14 days
find "$LOG_DIR" -type f -name "update-*.log" -mtime +14 -delete 2>/dev/null || true

# 11. Final summary and optional desktop notification
if [ "$ERRORS" -gt 0 ]; then
    FAILED_STR=$(IFS=", "; echo "${FAILED_COMPONENTS[*]}")
    log "=== Finished daily user-level software update with $ERRORS error(s): $FAILED_STR ==="
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u normal -i software-update-urgent \
            "Software Update Alert" \
            "Issues encountered updating: $FAILED_STR\nDetails in: $LOG_FILE" 2>/dev/null || true
    fi
else
    log "=== Finished daily user-level software update successfully ==="
fi
