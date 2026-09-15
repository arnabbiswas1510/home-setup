#!/usr/bin/env python3
"""
Auto-renames GPU Screen Recorder videos based on the active/latest video tab in Firefox or browser.
Also automatically routes browser audio (Firefox, Chrome, etc.) to the SilentRecording
null sink while recording is active, ensuring physical speakers remain completely silent
while the recording cleanly captures the audio, and restores audio to speakers when done.
"""

import os
import sys
import time
import glob
import json
import struct
import ctypes
import re
import shutil
import subprocess
from pathlib import Path

VIDEOS_DIR = Path.home() / "Videos"

MEDIA_APP_KEYWORDS = [
    "firefox", "chrome", "chromium", "brave", "edge", "opera", "vivaldi",
    "mpv", "vlc", "iptvnator", "plex", "spotify", "celluloid", "totem",
    "electron", "webcord", "discord"
]

def notify(title, message):
    if shutil.which("notify-send"):
        try:
            subprocess.run(["notify-send", "-a", "GPU Screen Recorder", "-i", "media-record", title, message], check=False)
            return
        except Exception:
            pass
    if shutil.which("kdialog"):
        try:
            subprocess.run(["kdialog", "--passivepopup", f"{title}\n{message}", "5"], check=False)
            return
        except Exception:
            pass

def slug_to_title(slug):
    slug = re.sub(r'\.(html|php|mp4)$', '', slug)
    words = slug.split('-')
    res = []
    i = 0
    while i < len(words):
        w = words[i]
        if i == 0 and i + 1 < len(words) and re.match(r'^[a-zA-Z0-9]+$', w) and re.match(r'^\d+$', words[i+1]):
            res.append(f'{w.upper()}-{words[i+1]}')
            i += 2
            continue
        res.append(w.capitalize())
        i += 1
    return ' '.join(res)

def get_firefox_session_files():
    search_patterns = [
        str(Path.home() / ".config/mozilla/firefox/*.default*/sessionstore-backups/recovery.jsonlz4"),
        str(Path.home() / ".mozilla/firefox/*.default*/sessionstore-backups/recovery.jsonlz4"),
        str(Path.home() / ".var/app/org.mozilla.firefox/.config/mozilla/firefox/*.default*/sessionstore-backups/recovery.jsonlz4"),
        str(Path.home() / ".var/app/org.mozilla.firefox/.mozilla/firefox/*.default*/sessionstore-backups/recovery.jsonlz4"),
    ]
    paths = []
    for pat in search_patterns:
        paths.extend(glob.glob(pat))
    if not paths:
        for pat in [
            str(Path.home() / ".config/mozilla/firefox/*.default*/sessionstore-backups/previous.jsonlz4"),
            str(Path.home() / ".mozilla/firefox/*.default*/sessionstore-backups/previous.jsonlz4"),
        ]:
            paths.extend(glob.glob(pat))
    unique_paths = list(dict.fromkeys(paths))
    unique_paths.sort(key=os.path.getmtime, reverse=True)
    return unique_paths

def get_firefox_active_title():
    try:
        lz4 = ctypes.CDLL('liblz4.so.1')
        lz4.LZ4_decompress_safe.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int, ctypes.c_int]
        lz4.LZ4_decompress_safe.restype = ctypes.c_int

        paths = get_firefox_session_files()
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
            ad_keywords = [
                'google search', 'redirecting', 'just a moment', 'magic is loading',
                'age confirmation', 'faphouse', 'adult friend', 'casino', 'betting',
                'live cam', 'chaturbate', 'click here'
            ]
            for tab in all_tabs:
                raw_title = tab['title'].strip()
                tab_url = tab.get('url', '')
                if not raw_title or len(raw_title) < 2:
                    continue
                if any(k in raw_title.lower() for k in ad_keywords):
                    continue
                if any(k in tab_url.lower() for k in ad_keywords):
                    continue

                m = re.search(r'/video/([^/?#]+)', tab_url)
                if m:
                    extracted = slug_to_title(m.group(1))
                    if extracted and len(extracted) > 4:
                        return extracted

                cleaned = re.sub(r' - (BestJavPorn|YouTube|Vimeo|Twitch|Dailymotion|Netflix|Adult).*$', '', raw_title, flags=re.IGNORECASE).strip()
                cleaned = re.sub(r'[\\/*?:"<>|]', '', cleaned).strip()
                if cleaned and len(cleaned) > 2:
                    return cleaned
    except Exception as e:
        print(f"Error extracting Firefox title: {e}", file=sys.stderr)
    return None

def get_kwin_browser_title():
    js = """
    var out = [];
    for (var i = 0; i < workspace.windowList().length; i++) {
        var c = workspace.windowList()[i];
        if (c.normalWindow && (c.resourceClass.indexOf('firefox') !== -1 || c.resourceClass.indexOf('chrome') !== -1)) {
            out.push(c.caption);
        }
    }
    console.info('GSR_TITLE:' + out.join('%%%'));
    """
    tmp_js = "/tmp/gsr_title.js"
    try:
        with open(tmp_js, "w") as f:
            f.write(js)
        id_str = subprocess.check_output(
            ["qdbus6", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting.loadScript", tmp_js],
            text=True
        ).strip()
        subprocess.run(["qdbus6", "org.kde.KWin", f"/Scripting/Script{id_str}", "org.kde.kwin.Script.run"], capture_output=True)
        subprocess.run(["qdbus6", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting.unloadScript", id_str], capture_output=True)
        res = subprocess.check_output(["journalctl", "--user", "-b", "-n", "15", "--no-pager"], text=True)
        for line in reversed(res.splitlines()):
            if "GSR_TITLE:" in line:
                raw = line.split("GSR_TITLE:")[1].strip()
                for t in raw.split("%%%"):
                    cleaned = re.sub(r' - (BestJavPorn|YouTube|Vimeo|Twitch|Dailymotion|Netflix|Mozilla Firefox|Google Chrome).*$', '', t, flags=re.IGNORECASE).strip()
                    cleaned = re.sub(r' — (Mozilla Firefox|Google Chrome).*$', '', cleaned, flags=re.IGNORECASE).strip()
                    cleaned = re.sub(r'[\\/*?:"<>|]', '', cleaned).strip()
                    if cleaned and len(cleaned) > 2:
                        return cleaned
    except Exception:
        pass
    finally:
        if os.path.exists(tmp_js):
            try:
                os.remove(tmp_js)
            except OSError:
                pass
    return None

def get_best_title():
    title = get_firefox_active_title()
    if title:
        return title
    title = get_kwin_browser_title()
    if title:
        return title
    return None

def is_recording_in_progress():
    try:
        out = subprocess.check_output(["pgrep", "-f", "gpu-screen-recorder"], text=True)
        for pid in out.splitlines():
            pid = pid.strip()
            if not pid or pid == str(os.getpid()):
                continue
            try:
                cmdline = Path(f"/proc/{pid}/cmdline").read_bytes().decode("utf-8", errors="ignore")
                if "gpu-screen-recorder" in cmdline and ("-w" in cmdline or "-o" in cmdline or "-ro" in cmdline):
                    return True
            except Exception:
                pass
    except Exception:
        pass
    return False

def ensure_silent_sink():
    try:
        sinks = subprocess.check_output(["pactl", "list", "short", "sinks"], text=True)
        if "SilentRecording" not in sinks:
            subprocess.run([
                "pactl", "load-module", "module-null-sink",
                "sink_name=SilentRecording",
                "sink_properties=device.description=Silent_Recording"
            ], capture_output=True)
    except Exception:
        pass

def auto_route_audio_to_silent():
    """
    Routes active browser/media audio streams to SilentRecording sink
    so no sound comes out of the physical speakers, but the audio is captured by GPU Screen Recorder.
    """
    try:
        ensure_silent_sink()
        sinks = subprocess.check_output(["pactl", "list", "short", "sinks"], text=True)
        silent_sink_num = None
        for line in sinks.splitlines():
            parts = line.split()
            if len(parts) >= 2 and "SilentRecording" in parts[1]:
                silent_sink_num = parts[0]
                break
        if not silent_sink_num:
            return

        out = subprocess.check_output(["pactl", "list", "sink-inputs"], text=True)
        blocks = out.split("Sink Input #")

        for b in blocks[1:]:
            lines = b.splitlines()
            id_val = lines[0].strip()
            app_name = ""
            sink_id = ""
            for l in lines:
                if "application.name =" in l:
                    app_name = l.split("=")[1].strip().strip('"').lower()
                elif "Sink:" in l:
                    sink_id = l.split(":")[1].strip()

            if any(k in app_name for k in MEDIA_APP_KEYWORDS):
                if sink_id != silent_sink_num:
                    subprocess.run(["pactl", "move-sink-input", id_val, "SilentRecording"], capture_output=True)
                    print(f"Auto-routed {app_name} (stream #{id_val}) to SilentRecording (silent on speakers, recording sound)")
    except Exception as e:
        pass

def restore_audio_to_default():
    """
    Restores any audio streams currently on SilentRecording back to the default output.
    """
    try:
        sinks = subprocess.check_output(["pactl", "list", "short", "sinks"], text=True)
        silent_sink_num = None
        for line in sinks.splitlines():
            parts = line.split()
            if len(parts) >= 2 and "SilentRecording" in parts[1]:
                silent_sink_num = parts[0]
                break
        if not silent_sink_num:
            return

        out = subprocess.check_output(["pactl", "list", "sink-inputs"], text=True)
        blocks = out.split("Sink Input #")
        for b in blocks[1:]:
            lines = b.splitlines()
            id_val = lines[0].strip()
            sink_id = ""
            for l in lines:
                if "Sink:" in l:
                    sink_id = l.split(":")[1].strip()
            if sink_id == silent_sink_num:
                subprocess.run(["pactl", "move-sink-input", id_val, "@DEFAULT_SINK@"], capture_output=True)
                print(f"Restored stream #{id_val} back to default speakers.")
    except Exception:
        pass

def is_file_open(file_path):
    file_path = Path(file_path).resolve()
    # Check /proc/*/fd directly
    try:
        for pid_dir in Path("/proc").iterdir():
            if not pid_dir.name.isdigit():
                continue
            fd_dir = pid_dir / "fd"
            if not fd_dir.exists():
                continue
            try:
                for fd in fd_dir.iterdir():
                    try:
                        if fd.resolve() == file_path:
                            return True
                    except (OSError, RuntimeError):
                        pass
            except (PermissionError, OSError):
                pass
    except Exception:
        pass

    # Fallback to fuser if available
    if shutil.which("fuser"):
        try:
            res = subprocess.run(["fuser", str(file_path)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return res.returncode == 0
        except Exception:
            pass

    return False

def is_file_size_stable(file_path, wait_sec=1):
    try:
        s1 = os.path.getsize(file_path)
        time.sleep(wait_sec)
        s2 = os.path.getsize(file_path)
        return s1 == s2 and s1 > 1024 * 50  # at least 50 KB
    except Exception:
        return False

def get_candidate_recordings():
    candidates = []
    for pattern in ("Video_*.mp4", "Video_*.mkv", "Recording_*.mp4", "Recording_*.mkv"):
        candidates.extend(VIDEOS_DIR.glob(pattern))
    return sorted(candidates, key=os.path.getmtime, reverse=True)

def find_latest_unnamed_recording():
    candidates = get_candidate_recordings()
    return candidates[0] if candidates else None

def rename_recording(video_path, custom_title=None):
    if not video_path or not os.path.exists(video_path):
        return None
    
    # Ensure file is completely closed by recorder
    if is_file_open(video_path):
        return None

    # Ensure size is stable
    if not is_file_size_stable(video_path, wait_sec=1):
        return None

    title = custom_title or get_best_title()
    if not title:
        print(f"Warning: No valid title found for {video_path}", file=sys.stderr)
        return None

    ext = Path(video_path).suffix
    target_name = f"{title}{ext}"
    target_path = VIDEOS_DIR / target_name

    # Avoid overwriting existing files
    counter = 1
    while target_path.exists():
        if target_path.resolve() == Path(video_path).resolve():
            return str(target_path)
        target_name = f"{title}_{counter}{ext}"
        target_path = VIDEOS_DIR / target_name
        counter += 1

    try:
        shutil.move(str(video_path), str(target_path))
        notify("Recording Saved", f"Renamed to:\n{target_name}")
        print(f"Successfully renamed {Path(video_path).name} -> {target_name}")
        return str(target_path)
    except Exception as e:
        print(f"Error renaming {video_path}: {e}", file=sys.stderr)
        return None

def watch_directory():
    print(f"Watching {VIDEOS_DIR} for completed recordings and auto-routing audio to SilentRecording...")
    processed_files = set()
    failed_attempts = {}
    was_recording = False

    while True:
        try:
            recording_active = is_recording_in_progress()

            if recording_active:
                if not was_recording:
                    print("Recording started. Monitoring audio streams...")
                    was_recording = True
                auto_route_audio_to_silent()
            else:
                if was_recording:
                    print("Recording stopped. Restoring audio and finalizing recording...")
                    was_recording = False
                    restore_audio_to_default()
                    time.sleep(1.5)  # Grace period for recorder to flush container and close fd

            candidates = get_candidate_recordings()
            for cand in candidates:
                cand_str = str(cand.resolve())
                if cand_str in processed_files:
                    continue
                
                # If recording is active and this file is currently open or freshly modified, skip renaming
                if is_file_open(cand):
                    continue

                if recording_active:
                    try:
                        if time.time() - os.path.getmtime(cand) < 10:
                            continue
                    except OSError:
                        continue
                
                # File is closed, verify size
                try:
                    file_size = os.path.getsize(cand)
                except OSError:
                    continue

                if file_size < 1024 * 50:  # Skip tiny / empty files
                    processed_files.add(cand_str)
                    continue
                
                attempts = failed_attempts.get(cand_str, 0)
                if attempts >= 15:
                    processed_files.add(cand_str)
                    continue

                print(f"Recording finished: {cand.name}. Renaming...")
                res = rename_recording(cand)
                if res:
                    processed_files.add(cand_str)
                    processed_files.add(str(Path(res).resolve()))
                    failed_attempts.pop(cand_str, None)
                else:
                    failed_attempts[cand_str] = attempts + 1
        except Exception as e:
            print(f"Watcher loop error: {e}", file=sys.stderr)
        
        time.sleep(1)

def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--watch":
        watch_directory()
    elif len(sys.argv) > 1 and sys.argv[1] == "--file":
        if len(sys.argv) > 2:
            rename_recording(sys.argv[2])
    else:
        latest = find_latest_unnamed_recording()
        if latest:
            res = rename_recording(latest)
            if res:
                print(f"Renamed: {res}")
            else:
                print("Could not detect title or rename.")
        else:
            print("No pending unnamed recording files found.")

if __name__ == "__main__":
    main()
