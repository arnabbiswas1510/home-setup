#!/usr/bin/env python3
"""
Auto-renames GPU Screen Recorder videos based on the active/latest video tab in Firefox.
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

                # If URL contains video slug, check it
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

def is_file_open(file_path):
    try:
        res = subprocess.run(["fuser", str(file_path)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return res.returncode == 0
    except Exception:
        return False

def is_file_size_stable(file_path, wait_sec=2):
    try:
        s1 = os.path.getsize(file_path)
        time.sleep(wait_sec)
        s2 = os.path.getsize(file_path)
        return s1 == s2 and s1 > 1024 * 100  # at least 100 KB
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
    
    # Ensure file is completely closed
    while is_file_open(video_path):
        time.sleep(2)

    # Ensure size is stable
    if not is_file_size_stable(video_path, wait_sec=2):
        return None

    title = custom_title or get_firefox_active_title()
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
        subprocess.run(["notify-send", "-a", "GPU Screen Recorder", "Recording Saved", f"Renamed to:\n{target_name}"], check=False)
        print(f"Successfully renamed {Path(video_path).name} -> {target_name}")
        return str(target_path)
    except Exception as e:
        print(f"Error renaming {video_path}: {e}", file=sys.stderr)
        return None

def watch_directory():
    print(f"Watching {VIDEOS_DIR} for completed recordings...")
    processed_files = set()
    
    while True:
        try:
            candidates = get_candidate_recordings()
            for cand in candidates:
                cand_str = str(cand.resolve())
                if cand_str in processed_files:
                    continue
                
                # Check if recording is still writing
                if is_file_open(cand):
                    # Still recording, check back on next cycle
                    continue
                
                # File is closed, verify size
                if os.path.getsize(cand) < 1024 * 50:  # Skip empty or aborted files
                    continue
                
                print(f"Recording finished: {cand.name}. Renaming...")
                res = rename_recording(cand)
                if res:
                    processed_files.add(cand_str)
                    processed_files.add(str(Path(res).resolve()))
        except Exception as e:
            print(f"Watcher loop error: {e}", file=sys.stderr)
        
        time.sleep(2)

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
