#!/usr/bin/env bash
# Ensures the silent sink is loaded and routes all browser audio into it

pactl load-module module-null-sink sink_name=SilentRecording sink_properties=device.description="Silent_Recording" 2>/dev/null || true

for id in $(pactl list sink-inputs | grep -B 20 -i -E "application.name = \"(firefox|chrome|chromium)\"" | grep "Sink Input #" | awk -F'#' '{print $2}'); do
    pactl move-sink-input "$id" SilentRecording
    echo "Routed browser audio (stream #$id) to Silent_Recording"
done
