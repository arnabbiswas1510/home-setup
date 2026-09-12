#!/usr/bin/env python3
"""
Batch Video Recorder for Firefox on KDE Plasma (Wayland)
Automates:
1. Moving Firefox to Desktop 2
2. Playing video & recording simultaneously via GPU Screen Recorder
3. Auto-detecting when video finishes via PipeWire audio activity
4. Renaming video files automatically with the video's web title
5. Looping through all provided URLs sequentially
"""

import os
import sys
import time
import json
import glob
import struct
import ctypes
import re
import shutil
import subprocess
from pathlib import Path

VIDEOS_DIR = Path.home() / "Videos"
RESTORE_TOKEN = Path.home() / ".var/app/com.dec05eba.gpu_screen_recorder/config/gpu-screen-recorder/restore_token"
URLS_FILE = Path.home() / "urls.txt"

def notify(title, message):
    subprocess.run(["notify-send", "-a", "Batch Recorder", "-i", "media-record", title, message], check=False)

def ensure_silent_sink():
    # Make sure SilentRecording sink is loaded
    subprocess.run([
        "pactl", "load-module", "module-null-sink",
        "sink_name=SilentRecording",
        "sink_properties=device.description=Silent_Recording"
    ], capture_output=True)

def move_firefox_to_desktop2():
    js_code = """
    var clients = workspace.windowList();
    for (var i = 0; i < clients.length; i++) {
        var c = clients[i];
        if (c.resourceClass === "firefox" || c.resourceClass === "firefox-esr") {
            if (workspace.desktops.length > 1) {
                c.desktops = [workspace.desktops[1]];
            }
        }
    }
    """
    tmp_path = "/tmp/mv_firefox_desktop2.js"
    try:
        with open(tmp_path, "w") as f:
            f.write(js_code)
        id_str = subprocess.check_output(
            ["qdbus6", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting.loadScript", tmp_path, "mv_ff_d2"],
            text=True
        ).strip()
        subprocess.run(["qdbus6", "org.kde.KWin", f"/Scripting/Script{id_str}", "org.kde.kwin.Script.run"], capture_output=True)
        subprocess.run(["qdbus6", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting.unloadScript", "mv_ff_d2"], capture_output=True)
    except Exception as e:
        print(f"Warning: Could not move window to Desktop 2: {e}", file=sys.stderr)
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

def get_firefox_active_title():
    try:
        lz4 = ctypes.CDLL('liblz4.so.1')
        lz4.LZ4_decompress_safe.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int, ctypes.c_int]
        lz4.LZ4_decompress_safe.restype = ctypes.c_int

        paths = glob.glob(str(Path.home() / ".mozilla/firefox/*.default*/sessionstore-backups/recovery.jsonlz4"))
        if not paths:
            return None

        with open(paths[0], 'rb') as f:
            magic = f.read(8)
            if magic != b'mozLz40\0':
                return None
            uncompressed_size = struct.unpack('<I', f.read(4))[0]
            comp_data = f.read()
            dst_buf = ctypes.create_string_buffer(uncompressed_size)
            res = lz4.LZ4_decompress_safe(comp_data, dst_buf, len(comp_data), uncompressed_size)
            if res <= 0:
                return None

            data = json.loads(dst_buf.raw[:res].decode('utf-8'))
            all_tabs = []
            for w in data.get('windows', []):
                for t in w.get('tabs', []):
                    idx = t.get('index', 1) - 1
                    entries = t.get('entries', [])
                    if 0 <= idx < len(entries):
                        title = entries[idx].get('title', '')
                        url = entries[idx].get('url', '')
                        last_acc = t.get('lastAccessed', 0)
                        all_tabs.append({'title': title, 'url': url, 'lastAccessed': last_acc})

            all_tabs.sort(key=lambda x: x['lastAccessed'], reverse=True)
            for tab in all_tabs:
                raw_title = tab['title'].strip()
                if not raw_title or len(raw_title) < 2:
                    continue
                if any(x in raw_title.lower() for x in ['google search', 'redirecting', 'just a moment', 'magic is loading', 'age confirmation']):
                    continue
                cleaned = re.sub(r' - (BestJavPorn|YouTube|Vimeo|Twitch|Dailymotion|Netflix).*$', '', raw_title, flags=re.IGNORECASE).strip()
                cleaned = re.sub(r'[\\/*?:"<>|]', '', cleaned).strip()
                if cleaned:
                    return cleaned
    except Exception:
        pass
    return None

def wait_for_video_playback(timeout=30):
    """
    Waits for Firefox to start audio playback.
    Routes audio to SilentRecording.
    Returns sink-input ID.
    """
    start = time.time()
    while time.time() - start < timeout:
        try:
            out = subprocess.check_output(["pactl", "list", "sink-inputs"], text=True)
            blocks = out.split("Sink Input #")
            for b in blocks[1:]:
                if 'application.name = "Firefox"' in b:
                    id_val = b.splitlines()[0].strip()
                    if 'Corked: no' in b:
                        # Route directly into SilentRecording
                        subprocess.run(["pactl", "move-sink-input", id_val, "SilentRecording"], capture_output=True)
                        return id_val
        except Exception:
            pass
        time.sleep(1)
    return None

def get_unique_filepath(base_title):
    safe_title = re.sub(r'[\\/*?:"<>|]', '', base_title).strip()
    if not safe_title:
        safe_title = f"Recording_{int(time.time())}"
    
    target = VIDEOS_DIR / f"{safe_title}.mp4"
    counter = 1
    while target.exists():
        target = VIDEOS_DIR / f"{safe_title}_{counter}.mp4"
        counter += 1
    return target

def record_video_session(url, index, total):
    print(f"\n[{index}/{total}] Opening: {url}")
    notify(f"Processing ({index}/{total})", f"Opening in Firefox on Desktop 2:\n{url}")

    # 1. Open URL in Firefox
    subprocess.Popen(["firefox", url])
    time.sleep(3)

    # 2. Push to Desktop 2
    move_firefox_to_desktop2()

    # 3. Wait for playback to begin
    print("Waiting for video playback to start...")
    sink_id = wait_for_video_playback(timeout=25)
    if not sink_id:
        print("Warning: Audio stream not detected within 25s. Proceeding with recording anyway...")

    # Grab the page title
    time.sleep(2)
    title = get_firefox_active_title() or f"Video_{time.strftime('%Y-%m-%d_%H-%M-%S')}"
    target_path = get_unique_filepath(title)
    print(f"Target recording path: {target_path}")

    # 4. Start GPU Screen Recorder
    cmd = [
        "flatpak", "run", "--command=gpu-screen-recorder", "com.dec05eba.gpu_screen_recorder",
        "-w", "portal",
        "-restore-portal-session", "yes",
        "-portal-session-token-filepath", str(RESTORE_TOKEN),
        "-k", "hevc",
        "-q", "high",
        "-f", "30",
        "-fm", "content",
        "-s", "1920x1080",
        "-c", "mp4",
        "-a", "SilentRecording.monitor",
        "-o", str(target_path)
    ]

    print(f"Starting screen recorder...")
    proc = subprocess.Popen(cmd)
    notify(f"Recording ({index}/{total})", f"Started: {target_path.name}")

    # 5. Monitor until all episodes in this link end
    EPISODE_TRANSITION_TIMEOUT = 35  # seconds to wait between episodes before concluding
    silence_seconds = 0
    episodes_recorded = 1
    has_played = False
    start_time = time.time()
    time.sleep(6)  # initial grace period

    while True:
        time.sleep(2)
        try:
            out = subprocess.check_output(["pactl", "list", "sink-inputs"], text=True)
            firefox_playing = False
            blocks = out.split("Sink Input #")
            for b in blocks[1:]:
                if 'application.name = "Firefox"' in b:
                    id_val = b.splitlines()[0].strip()
                    # Ensure audio is always piped to SilentRecording
                    subprocess.run(["pactl", "move-sink-input", id_val, "SilentRecording"], capture_output=True)
                    if 'Corked: no' in b:
                        firefox_playing = True
                        has_played = True
                        break

            if not firefox_playing:
                if has_played:
                    silence_seconds += 2
                    if silence_seconds == 6:
                        print("Audio paused. Waiting to see if next episode begins...")
                        notify(f"Link ({index}/{total})", f"Episode {episodes_recorded} finished/paused. Waiting for next episode...")
                    elif silence_seconds >= EPISODE_TRANSITION_TIMEOUT:
                        print(f"All episodes completed for this link ({episodes_recorded} episode(s) recorded).")
                        break
            else:
                if silence_seconds >= 6:
                    episodes_recorded += 1
                    print(f"Next episode detected (Episode {episodes_recorded})! Continuing recording into same file...")
                    notify(f"Link ({index}/{total})", f"Episode {episodes_recorded} started! Recording into same file...")
                silence_seconds = 0
        except Exception:
            pass

    # 6. Stop recording (1 URL == 1 finalized MP4 containing all its episodes)
    print("Finalizing video recording...")
    subprocess.run(["killall", "-SIGINT", "gpu-screen-recorder"], capture_output=True)
    try:
        proc.wait(timeout=10)
    except subprocess.TimeoutExpired:
        proc.kill()

    # Wait for file close
    time.sleep(2)
    notify(f"Completed ({index}/{total})", f"Saved:\n{target_path.name}\n({episodes_recorded} episode(s) captured)")
    print(f"Successfully saved: {target_path} (Episodes: {episodes_recorded})")

def get_url_list():
    # If passed as command line argument (e.g. batch-recorder.py urls.txt)
    if len(sys.argv) > 1 and os.path.isfile(sys.argv[1]):
        with open(sys.argv[1]) as f:
            return [line.strip() for line in f if line.strip() and not line.strip().startswith("#")]

    # If ~/urls.txt exists and has URLs
    default_urls = []
    if URLS_FILE.exists():
        with open(URLS_FILE) as f:
            default_urls = [line.strip() for line in f if line.strip() and not line.strip().startswith("#")]

    # Interactive GUI prompt via kdialog
    init_text = "\n".join(default_urls) if default_urls else "https://\n"
    res = subprocess.run([
        "kdialog", "--title", "Batch Video Recorder",
        "--textinputbox",
        "Enter or paste video URLs to record (one per line):",
        init_text
    ], capture_output=True, text=True)

    if res.returncode != 0:
        return []

    lines = [l.strip() for l in res.stdout.splitlines() if l.strip() and l.strip().startswith("http")]
    if lines:
        # Save back to ~/urls.txt for future convenience
        with open(URLS_FILE, "w") as f:
            f.write("\n".join(lines) + "\n")
    return lines

def is_recorder_running():
    try:
        out = subprocess.check_output(["pgrep", "-f", "gpu-screen-recorder"], text=True)
        for pid in out.splitlines():
            pid = pid.strip()
            if not pid or pid == str(os.getpid()):
                continue
            try:
                with open(f"/proc/{pid}/cmdline", "rb") as f:
                    cmd = f.read().decode("utf-8", errors="ignore")
                    if "gpu-screen-recorder" in cmd and "-w" in cmd and "-o" in cmd:
                        return True
            except Exception:
                pass
    except Exception:
        pass
    return False

def wait_for_existing_recording():
    """
    If a recording is already running (e.g. manual recording),
    wait until it completes before starting the batch.
    """
    if is_recorder_running():
        print("An active recording is currently running. Waiting for it to finish...")
        notify("Batch Recorder Queued", "An active recording is currently in progress.\nQueueing batch to start as soon as it finishes...")
        while is_recorder_running():
            time.sleep(4)
        print("Previous recording finished. Proceeding with batch queue...")
        time.sleep(3)
        notify("Batch Recorder", "Previous recording completed. Starting batch queue now!")

def main():
    ensure_silent_sink()
    urls = get_url_list()
    if not urls:
        print("No URLs provided or cancelled.")
        return

    # Check if a recording is currently in progress and wait if so
    wait_for_existing_recording()

    total = len(urls)
    notify("Batch Recorder", f"Starting batch recording for {total} video(s)...")

    for idx, url in enumerate(urls, start=1):
        record_video_session(url, idx, total)
        time.sleep(2)

    notify("Batch Recorder Complete", f"All {total} videos have been successfully recorded and saved to ~/Videos!")

if __name__ == "__main__":
    main()
