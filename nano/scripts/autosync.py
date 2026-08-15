#!/usr/bin/env python3
"""
Home Setup Automated Sync & Push Daemon for Nano Workstation
Watches packages, desktop configs, and system tweaks; updates home-setup repo,
and pushes semantic commits to GitHub automatically.
"""

import os
import sys
import time
import subprocess
import shutil
import tomllib
from pathlib import Path

REPO_ROOT = Path("/home/pom/workspace/home-setup")
NANO_DIR = REPO_ROOT / "nano"
HOSTS_TOML = NANO_DIR / ".chezmoidata" / "hosts.toml"
HOME = Path("/home/pom")

# Mapping of system config files to repo destinations
CONFIG_MAP = {
    HOME / ".bashrc": NANO_DIR / "dot_bashrc",
    HOME / ".profile": NANO_DIR / "dot_profile",
    HOME / ".config" / "kglobalshortcutsrc": NANO_DIR / "dot_config" / "kglobalshortcutsrc",
    HOME / ".config" / "kwinrc": NANO_DIR / "dot_config" / "kwinrc",
    HOME / ".config" / "kdeglobals": NANO_DIR / "dot_config" / "kdeglobals",
    HOME / ".config" / "konsolerc": NANO_DIR / "dot_config" / "konsolerc",
    HOME / ".config" / "spectaclerc": NANO_DIR / "dot_config" / "spectaclerc",
    HOME / ".config" / "dolphinrc": NANO_DIR / "dot_config" / "dolphinrc",
    HOME / ".config" / "mimeapps.list": NANO_DIR / "dot_config" / "mimeapps.list",
    HOME / ".config" / "qimgv" / "qimgv.conf": NANO_DIR / "dot_config" / "qimgv" / "qimgv.conf",
    HOME / ".config" / "yt-dlp" / "config": NANO_DIR / "dot_config" / "yt-dlp" / "config",
    HOME / ".config" / "IPTVnator" / "config.json": NANO_DIR / "dot_config" / "IPTVnator" / "config.json",
    HOME / ".local" / "share" / "konsole" / "MyProfile.profile": NANO_DIR / "dot_local" / "share" / "konsole" / "MyProfile.profile",
    HOME / ".local" / "share" / "user-places.xbel": NANO_DIR / "dot_local" / "share" / "user-places.xbel",
}

# Directories to mirror recursively
DIR_MAP = {
    HOME / ".config" / "autostart": NANO_DIR / "dot_config" / "autostart",
}

# System /etc files tracked in repo
ETC_DIR = NANO_DIR / "etc"

def run_cmd(cmd, cwd=REPO_ROOT, check=False):
    res = subprocess.run(cmd, cwd=cwd, shell=isinstance(cmd, str), capture_output=True, text=True)
    if check and res.returncode != 0:
        raise RuntimeError(f"Command failed: {cmd}\nStderr: {res.stderr}")
    return res

def get_installed_flatpaks():
    res = subprocess.run(["flatpak", "list", "--app", "--columns=application"], capture_output=True, text=True)
    if res.returncode != 0:
        return []
    return sorted([line.strip() for line in res.stdout.splitlines() if line.strip()])

def sync_flatpaks(changes):
    if not HOSTS_TOML.exists():
        return
    current_installed = get_installed_flatpaks()
    if not current_installed:
        return

    content = HOSTS_TOML.read_text()
    try:
        data = tomllib.loads(content)
        current_toml_flatpaks = data.get("hosts", {}).get("nano", {}).get("flatpak_apps", [])
    except Exception:
        return

    if sorted(current_installed) != sorted(current_toml_flatpaks):
        added = set(current_installed) - set(current_toml_flatpaks)
        removed = set(current_toml_flatpaks) - set(current_installed)
        
        # Format updated flatpak_apps list in TOML
        formatted_list = "flatpak_apps = [\n" + ",\n".join(f'  "{app}"' for app in current_installed) + "\n]"
        
        # Replace in TOML string
        import re
        new_content = re.sub(r'flatpak_apps\s*=\s*\[[^\]]*\]', formatted_list, content)
        if new_content != content:
            HOSTS_TOML.write_text(new_content)
            for a in added:
                changes.append(f"feat(nano/flatpak): add {a}")
            for r in removed:
                changes.append(f"refactor(nano/flatpak): remove {r}")

def sync_dotfiles(changes):
    for src, dst in CONFIG_MAP.items():
        if src.is_file():
            dst.parent.mkdir(parents=True, exist_ok=True)
            if not dst.exists() or src.read_bytes() != dst.read_bytes():
                shutil.copy2(src, dst)
                name = src.name
                changes.append(f"chore(nano/config): update {name}")

    for src_dir, dst_dir in DIR_MAP.items():
        if src_dir.is_dir():
            dst_dir.mkdir(parents=True, exist_ok=True)
            for item in src_dir.glob("*"):
                if item.is_file():
                    target = dst_dir / item.name
                    if not target.exists() or item.read_bytes() != target.read_bytes():
                        shutil.copy2(item, target)
                        changes.append(f"chore(nano/autostart): update {item.name}")

def sync_etc_files(changes):
    if not ETC_DIR.is_dir():
        return
    for item in ETC_DIR.rglob("*"):
        if item.is_file():
            rel_path = item.relative_to(ETC_DIR)
            sys_path = Path("/etc") / rel_path
            if sys_path.is_file():
                try:
                    if sys_path.read_bytes() != item.read_bytes():
                        shutil.copy2(sys_path, item)
                        changes.append(f"fix(nano/etc): update /etc/{rel_path}")
                except PermissionError:
                    pass

def reconcile_and_commit():
    changes = []
    sync_dotfiles(changes)
    sync_flatpaks(changes)
    sync_etc_files(changes)

    # Check git status
    res = run_cmd("git status --porcelain")
    status_out = res.stdout.strip()
    if not status_out:
        return False

    # Build semantic commit message
    if changes:
        title = changes[0]
        if len(changes) > 1:
            body = "\n".join(f"- {c}" for c in changes)
            commit_msg = f"chore(nano): sync system & config updates\n\n{body}"
        else:
            commit_msg = title
    else:
        # Fallback based on git status lines
        lines = [line.strip().split(maxsplit=1)[-1] for line in status_out.splitlines()]
        summary = ", ".join(lines[:3])
        commit_msg = f"chore(nano): automated sync of {summary}"

    print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Committing changes:\n{commit_msg}")
    run_cmd(["git", "add", "."], check=True)
    run_cmd(["git", "commit", "-m", commit_msg], check=True)
    
    # Push to origin
    push_res = run_cmd(["git", "push", "origin", "main"])
    if push_res.returncode == 0:
        print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Successfully pushed to origin/main.")
    else:
        print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Push failed:\n{push_res.stderr}")
    return True

def watch_loop():
    print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Starting home-setup auto-sync daemon...")
    while True:
        try:
            reconcile_and_commit()
        except Exception as e:
            print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Error during sync: {e}", file=sys.stderr)
        time.sleep(15)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--now":
        reconcile_and_commit()
    else:
        watch_loop()
