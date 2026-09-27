#!/usr/bin/env bash
set -u

LAST_RECORDED_APP=""

get_default_sink() {
    pactl get-default-sink
}

get_recorder_pid() {
    for pid in $(pgrep -f "gpu-screen-recorder" 2>/dev/null); do
        local cmd
        cmd=$(tr '\0' ' ' < /proc/"$pid"/cmdline 2>/dev/null || true)
        if [[ "$cmd" =~ (^|[ /])gpu-screen-recorder[[:space:]] ]] && [[ ! "$cmd" =~ gpu-screen-recorder-(gtk|ui) ]] && [[ ! "$cmd" =~ gsr-audio-auto-silence ]]; then
            echo "$pid"
            return
        fi
    done
}

detect_recorded_app() {
    local rpid="$1"
    local cmd
    cmd=$(tr '\0' ' ' < /proc/"$rpid"/cmdline 2>/dev/null || true)

    # 1. Check CLI args if recorded with -a app:AppName
    if [[ "$cmd" =~ -a[[:space:]]+app:([^[:space:]\|]+) ]]; then
        echo "${BASH_REMATCH[1]}"
        return
    fi

    # 2. Check PipeWire screencast stream name from KWin Wayland (kwin-screencast-<app>)
    local screencasts
    screencasts=$(pw-dump Node 2>/dev/null | jq -r '[.[] | select(.info.props."media.name"? | strings | startswith("kwin-screencast")) | .info.props."media.name"] | .[]' 2>/dev/null || true)
    
    for sc in $screencasts; do
        local target="${sc#kwin-screencast-}"
        if [[ -n "$target" ]] && [[ ! "$target" =~ ^(DP|HDMI|eDP|screen) ]]; then
            echo "$target"
            return
        fi
    done

    # 3. Fallback: Find the app actively playing audio
    local audio_apps
    audio_apps=$(pactl list sink-inputs 2>/dev/null | awk '/application.name =/ { print $3 }' | tr -d '"' | sort -u)
    for a in $audio_apps; do
        if [[ "$a" =~ (Firefox|firefox|chrome|chromium|mpv|vlc|spotify|netflix) ]]; then
            echo "$a"
            return
        fi
    done

    # If only one app is playing audio, pick it
    local count
    count=$(echo "$audio_apps" | wc -w)
    if [ "$count" -eq 1 ]; then
        echo "$audio_apps"
        return
    fi
}

move_app() {
    local app="$1"
    local sink="$2"
    pactl list sink-inputs | awk -v app="$app" -v sink="$sink" '
        /Sink Input #/ { id = substr($3, 2); matched = 0 }
        tolower($0) ~ tolower(app) { matched = 1 }
        /^$/ {
            if (matched && id != "") system("pactl move-sink-input " id " " sink " 2>/dev/null")
            id = ""; matched = 0
        }
        END {
            if (matched && id != "") system("pactl move-sink-input " id " " sink " 2>/dev/null")
        }
    '
}

cleanup() {
    if [ -n "$LAST_RECORDED_APP" ]; then
        local def_sink
        def_sink=$(get_default_sink)
        echo "Service stopping: restoring $LAST_RECORDED_APP to $def_sink"
        move_app "$LAST_RECORDED_APP" "$def_sink"
    fi
    exit 0
}
trap cleanup SIGINT SIGTERM

echo "GPU Screen Recorder Auto-Silence & Auto-Rename daemon started (v2 - strict PID & stream detection)."

while true; do
    RPID=$(get_recorder_pid)

    if [ -n "$RPID" ]; then
        # Recorder CLI is actively running
        APP=$(detect_recorded_app "$RPID")
        if [ -n "$APP" ]; then
            if [ "$APP" != "$LAST_RECORDED_APP" ]; then
                echo "Recording active (PID $RPID) -> Silencing '$APP' to silent_sink..."
                LAST_RECORDED_APP="$APP"
            fi
            # Continually keep any streams from this app on silent_sink
            move_app "$APP" "silent_sink"
        fi
    else
        # Recorder CLI is NOT running
        if [ -n "$LAST_RECORDED_APP" ]; then
            DEFAULT_SINK=$(get_default_sink)
            echo "Recording stopped. Restoring audio for '$LAST_RECORDED_APP' to '$DEFAULT_SINK'..."
            move_app "$LAST_RECORDED_APP" "$DEFAULT_SINK"
            LAST_RECORDED_APP=""

            # Automatically rename the newly finished recording with its detected title
            echo "Renaming recorded video with detected title..."
            /usr/bin/python3 /home/pom/.local/bin/gsr-rename-latest.py || true
        fi
    fi

    sleep 0.5
done
