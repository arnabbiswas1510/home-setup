#!/usr/bin/env python3
import subprocess
import re
import urllib.request
import urllib.parse
import os
import glob
import sqlite3
import shutil
from pathlib import Path

def get_mpris_info():
    try:
        out = subprocess.check_output(['qdbus'], text=True, stderr=subprocess.DEVNULL)
        for player in [l.strip() for l in out.splitlines() if 'org.mpris.MediaPlayer2' in l]:
            try:
                meta = subprocess.check_output(
                    ['qdbus', player, '/org/mpris/MediaPlayer2', 'org.freedesktop.DBus.Properties.Get', 'org.mpris.MediaPlayer2.Player', 'Metadata'],
                    text=True, stderr=subprocess.DEVNULL
                )
                title, url = '', ''
                for line in meta.splitlines():
                    if line.startswith('xesam:title:'):
                        title = line.split(':', 2)[2].strip()
                    elif line.startswith('xesam:url:'):
                        if 'https:' in line:
                            url = 'https:' + line.split('https:')[1].strip()
                if title or url:
                    return title, url
            except Exception:
                pass
    except Exception:
        pass
    return '', ''

def lookup_netflix_title(net_id):
    try:
        data = urllib.parse.urlencode({'q': f'netflix.com {net_id}'}).encode('utf-8')
        req = urllib.request.Request(
            'https://lite.duckduckgo.com/lite/',
            data=data,
            headers={'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0'}
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            html = resp.read().decode('utf-8', errors='ignore')
            for m in re.finditer(r"class='result-link'>([^<]+)<", html):
                t = m.group(1).strip()
                if 'netflix' in t.lower() and not t.lower().startswith('netflix -') and not t.lower() == 'netflix':
                    t = re.sub(r'(\s*-\s*Netflix.*|\s*\|\s*Netflix.*)', '', t, flags=re.I)
                    t = re.sub(r'^Watch\s+', '', t, flags=re.I)
                    if t.strip():
                        return t.strip()
    except Exception:
        pass
    return None

def get_netflix_ids_from_history():
    db_orig = Path.home() / '.config/mozilla/firefox/9vtt202c.default-release/places.sqlite'
    if not db_orig.exists():
        return []
    db_tmp = '/tmp/places_rename_query.sqlite'
    ids = []
    try:
        shutil.copy2(db_orig, db_tmp)
        conn = sqlite3.connect(db_tmp)
        cur = conn.cursor()
        cur.execute("""
            SELECT url FROM moz_places 
            WHERE url LIKE '%netflix.com/watch/%'
            ORDER BY last_visit_date DESC LIMIT 10
        """)
        for (u,) in cur.fetchall():
            m = re.search(r'netflix\.com/watch/(\d+)', u)
            if m:
                ids.append(m.group(1))
        conn.close()
        if os.path.exists(db_tmp):
            os.remove(db_tmp)
    except Exception:
        pass
    return list(dict.fromkeys(ids))

def get_recent_browser_media():
    db_orig = Path.home() / '.config/mozilla/firefox/9vtt202c.default-release/places.sqlite'
    if not db_orig.exists():
        return None
    db_tmp = '/tmp/places_rename_query2.sqlite'
    try:
        shutil.copy2(db_orig, db_tmp)
        conn = sqlite3.connect(db_tmp)
        cur = conn.cursor()
        cur.execute("""
            SELECT title FROM moz_places 
            WHERE url LIKE '%youtube.com/watch%'
            ORDER BY last_visit_date DESC LIMIT 1
        """)
        row = cur.fetchone()
        conn.close()
        if os.path.exists(db_tmp):
            os.remove(db_tmp)
        if row and row[0]:
            return row[0]
    except Exception:
        pass
    return None

def sanitize_title(title):
    # Clean up standard site suffixes
    title = re.sub(r'(\s*-\s*YouTube|\s*-\s*Twitch|\s*—\s*Mozilla Firefox|\s*-\s*Google Chrome)', '', title, flags=re.I)
    title = re.sub(r'(\s*-\s*Netflix|\s*\|\s*Netflix.*)', '', title, flags=re.I)
    title = re.sub(r'^Watch\s+', '', title, flags=re.I)
    # Replace illegal/unsafe characters with clean dash
    title = re.sub(r'[:/\\?*"<>|]', ' - ', title)
    title = re.sub(r'\s*-\s*-\s*', ' - ', title)
    title = re.sub(r'\s+', ' ', title).strip(' -')
    return title[:120].strip()

def find_latest_video():
    videos_dir = Path.home() / 'Videos'
    files = list(videos_dir.glob('Video_*.mp4'))
    if not files:
        return None
    files.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return files[0]

def main():
    target_file = find_latest_video()
    if not target_file:
        print("No Video_*.mp4 found to rename.")
        return

    # Check title
    title, url = get_mpris_info()
    detected_title = None

    if title and title.lower() != 'netflix':
        detected_title = sanitize_title(title)
    else:
        # Check Netflix
        net_ids = []
        if url:
            m = re.search(r'netflix\.com/watch/(\d+)', url)
            if m:
                net_ids.append(m.group(1))
        net_ids.extend(get_netflix_ids_from_history())
        for nid in net_ids:
            t = lookup_netflix_title(nid)
            if t:
                detected_title = sanitize_title(t)
                break

    if not detected_title:
        # Check YouTube or other recent browser media
        yt_title = get_recent_browser_media()
        if yt_title:
            detected_title = sanitize_title(yt_title)

    if not detected_title:
        print("Could not determine video title, keeping original filename.")
        return

    # Extract date/time from original filename Video_YYYY-MM-DD_HH-MM-SS.mp4
    orig_name = target_file.stem
    m = re.search(r'Video_(\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2})', orig_name)
    timestamp = m.group(1) if m else ""

    if timestamp:
        new_filename = f"{detected_title}_{timestamp}.mp4"
    else:
        new_filename = f"{detected_title}.mp4"

    new_path = target_file.parent / new_filename

    if target_file == new_path:
        print("File is already named correctly.")
        return

    # If destination exists, add increment
    counter = 1
    while new_path.exists():
        if timestamp:
            new_filename = f"{detected_title}_{timestamp}_{counter}.mp4"
        else:
            new_filename = f"{detected_title}_{counter}.mp4"
        new_path = target_file.parent / new_filename
        counter += 1

    print(f"Renaming: {target_file.name} -> {new_filename}")
    target_file.rename(new_path)
    print("Rename complete.")

if __name__ == '__main__':
    main()
