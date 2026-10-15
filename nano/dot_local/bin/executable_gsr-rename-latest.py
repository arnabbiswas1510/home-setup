#!/usr/bin/env python3
import subprocess
import re
import urllib.request
import urllib.parse
import os
import glob
import sqlite3
import shutil
from datetime import datetime
from pathlib import Path

def get_mpris_cmd():
    for cmd in ['qdbus6', 'qdbus']:
        if shutil.which(cmd):
            return cmd
    return None

def get_mpris_info():
    cmd = get_mpris_cmd()
    if not cmd:
        return '', ''
    try:
        out = subprocess.check_output([cmd], text=True, stderr=subprocess.DEVNULL)
        players = [l.strip() for l in out.splitlines() if 'org.mpris.MediaPlayer2' in l]
        # Ignore non-media players like Gwenview, image viewers
        ignored_players = ['gwenview', 'eog', 'shotwell', 'loupe']
        players = [p for p in players if not any(ign in p.lower() for ign in ignored_players)]
        
        for player in players:
            try:
                meta = subprocess.check_output(
                    [cmd, player, '/org/mpris/MediaPlayer2', 'org.freedesktop.DBus.Properties.Get', 'org.mpris.MediaPlayer2.Player', 'Metadata'],
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

def is_ad_or_junk(url, title):
    u = url.lower()
    ad_tokens = [
        "click", "pop", "affise", "tracker", "doubleclick",
        "juicyads", "traffic", "camsk", "chaturbate", "cupidnets", "splendid-garage",
        "ethnicexpressions", "cardiaccrystaleternity", "alexatracker", "gaming-adult",
        "collect", "sklnk", "rdl/e", "redirect", "google.com/search", "duckduckgo.com", "bing.com"
    ]
    if any(tok in u for tok in ad_tokens):
        return True
    return False

def clean_slug_to_title(slug):
    slug = re.sub(r"-(javout|fhd|720p|1080p|4k|hd|mp4)-", "-", slug, flags=re.I)
    slug = re.sub(r"-(javout|fhd|720p|1080p|4k|hd|mp4)$", "", slug, flags=re.I)
    slug = re.sub(r"^(javout|fhd|720p|1080p|4k|hd|mp4)-", "", slug, flags=re.I)
    parts = slug.split("-")
    cleaned_parts = []
    i = 0
    while i < len(parts):
        p = parts[i]
        if not p:
            i += 1
            continue
        if re.match(r"^[a-zA-Z]{2,6}$", p) and i + 1 < len(parts) and re.match(r"^\d{2,5}$", parts[i+1]):
            cleaned_parts.append(f"{p.upper()}-{parts[i+1]}")
            i += 2
            continue
        cleaned_parts.append(p.capitalize())
        i += 1
    return " ".join(cleaned_parts)

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
            bad_netflix_terms = [
                'unrecognized', 'unauthorized', 'charge', 'billing', 'account',
                'login', 'sign in', 'help center', 'support', 'terms', 'privacy',
                'cancel', 'error', 'password'
            ]
            for m in re.finditer(r"class='result-link'>([^<]+)<", html):
                t = m.group(1).strip()
                t_lower = t.lower()
                if any(bad in t_lower for bad in bad_netflix_terms):
                    continue
                if 'netflix' in t_lower and not t_lower.startswith('netflix -') and not t_lower == 'netflix':
                    t = re.sub(r'(\s*-\s*Netflix.*|\s*\|\s*Netflix.*)', '', t, flags=re.I)
                    t = re.sub(r'^Watch\s+', '', t, flags=re.I)
                    if t.strip():
                        return t.strip()
    except Exception:
        pass
    return None

def get_browser_history_entries(win_start, win_end):
    entries = []
    
    # 1. Firefox
    profiles = list(Path.home().glob('.config/mozilla/firefox/*.default*')) + list(Path.home().glob('.mozilla/firefox/*.default*'))
    for prof in profiles:
        db_orig = prof / 'places.sqlite'
        if not db_orig.exists():
            continue
        db_tmp = f'/tmp/places_query_{os.getpid()}.sqlite'
        try:
            shutil.copy2(db_orig, db_tmp)
            conn = sqlite3.connect(db_tmp)
            cur = conn.cursor()
            cur.execute("""
                SELECT url, title, (last_visit_date / 1000000) as ts
                FROM moz_places 
                WHERE (last_visit_date / 1000000) BETWEEN ? AND ?
                ORDER BY last_visit_date DESC
            """, (win_start, win_end))
            for row in cur.fetchall():
                entries.append(row)
            conn.close()
        except Exception:
            pass
        finally:
            if os.path.exists(db_tmp):
                os.remove(db_tmp)

    # 2. Chrome
    chrome_history = Path.home() / '.config/google-chrome/Default/History'
    if chrome_history.exists():
        db_tmp = f'/tmp/chrome_history_{os.getpid()}.sqlite'
        try:
            shutil.copy2(chrome_history, db_tmp)
            conn = sqlite3.connect(db_tmp)
            cur = conn.cursor()
            chrome_start = int((win_start + 11644473600) * 1000000)
            chrome_end = int((win_end + 11644473600) * 1000000)
            cur.execute("""
                SELECT url, title, ((last_visit_time / 1000000) - 11644473600) as ts
                FROM urls
                WHERE last_visit_time BETWEEN ? AND ?
                ORDER BY last_visit_time DESC
            """, (chrome_start, chrome_end))
            for row in cur.fetchall():
                entries.append(row)
            conn.close()
        except Exception:
            pass
        finally:
            if os.path.exists(db_tmp):
                os.remove(db_tmp)

    return entries

def is_video_url(url):
    u = url.lower()
    return any(k in u for k in ["/video/", "/watch", "youtu.be", "netflix.com/watch", "/play/", "/movie/"])

def is_generic_title(title):
    if not title:
        return True
    t = title.lower().strip()
    generic_list = [
        "(1) new message", "loading", "wait a moment", "magic is loading",
        "redirecting", "just a moment", "attention", "watch online",
        "mature content notice"
    ]
    return any(g in t for g in generic_list)

def detect_title_from_browser(win_start, win_end, start_ts):
    entries = get_browser_history_entries(win_start, win_end)
    candidates = []
    
    for url, title, ts in entries:
        if is_ad_or_junk(url, title):
            continue
        if is_video_url(url):
            score = abs(ts - start_ts)
            candidates.append((score, url, title, ts))
            
    if not candidates:
        return None
        
    # Pick the video visited closest to the recording start
    candidates.sort(key=lambda x: x[0])
    _, best_url, best_title, _ = candidates[0]
    
    # 1. Netflix check
    m_net = re.search(r'netflix\.com/watch/(\d+)', best_url)
    if m_net:
        net_title = lookup_netflix_title(m_net.group(1))
        if net_title:
            return sanitize_title(net_title)
            
    # 2. Check if title is valid and non-generic
    if best_title and not is_generic_title(best_title):
        return sanitize_title(best_title)
        
    # 3. Fallback to extracting title from URL slug
    m_slug = re.search(r'/(?:video|watch|movie)/([a-zA-Z0-9_\-]+)', best_url)
    if m_slug:
        slug = m_slug.group(1)
        cleaned = clean_slug_to_title(slug)
        if cleaned:
            return sanitize_title(cleaned)
            
    return None

def sanitize_title(title):
    # Clean up standard site suffixes
    title = re.sub(r'(\s*-\s*YouTube|\s*-\s*Twitch|\s*—\s*Mozilla Firefox|\s*-\s*Google Chrome|\s*-\s*BestJavPorn)', '', title, flags=re.I)
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

    orig_name = target_file.stem
    m = re.search(r'Video_(\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2})', orig_name)
    timestamp = m.group(1) if m else ""

    end_ts = target_file.stat().st_mtime
    if timestamp:
        try:
            start_dt = datetime.strptime(timestamp, "%Y-%m-%d_%H-%M-%S")
            start_ts = start_dt.timestamp()
        except Exception:
            start_ts = end_ts - 7200
    else:
        start_ts = end_ts - 7200

    # Strictly limit detection to the recording time window (-5m before start to +1m after end)
    win_start = start_ts - 300
    win_end = end_ts + 60

    # 1. Check MPRIS (active desktop media players)
    title, url = get_mpris_info()
    detected_title = None

    if title and not is_generic_title(title) and title.lower() not in ['netflix', 'youtube', 'gwenview', 'vlc']:
        detected_title = sanitize_title(title)

    # 2. Check browser history strictly within the recording window
    if not detected_title:
        detected_title = detect_title_from_browser(win_start, win_end, start_ts)

    if not detected_title:
        print("Could not determine video title, keeping original filename.")
        return

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
