# Nano Machine Setup (`nano`)

Minimal, portable dotfile configurations managed by [chezmoi](https://www.chezmoi.io/) for the **Nano** workstation.

---

## 🎯 Architecture & Philosophy

1. **Strictly Minimal & Dotfile-Focused**: Chezmoi is used solely to configure already-installed applications via minimal, portable dotfiles committed to this repository. Heavy automated package installers, OS scripts, and distribution-locked `/etc` files have been removed.
2. **Decoupled Software Installation**: Vanilla applications are installed separately using the native/best tool for the OS (e.g. `pacman`/`paru` on Arch/CachyOS, `brew` on macOS/Linux, `apt` on Debian/Ubuntu, or Flatpak).
3. **Software Inventory**: All applications are cataloged in [`apps.yaml`](./apps.yaml) for easy manual installation and reference.
4. **Cross-Platform Portability**: Dotfiles use chezmoi templates (`{{ .chezmoi.homeDir }}`) and `.chezmoiignore` so they apply cleanly across Linux distributions or macOS without modification.

---

## 📋 Software Inventory (`apps.yaml`)

Refer to [`apps.yaml`](./apps.yaml) to install the vanilla applications on a fresh machine:

```yaml
- Chezmoi list:
    CLI:
      - chezmoi
      - linuxbrew
      - yt-dlp (includes deno)
      - syncthing
      - freshbing
      - ffmpeg
    UI:
      - VSCode
      - VLC
      - Zoom
      - gpu-screen-recorder
      - iptvnator
      - Plex Desktop
      - Jellyfin Desktop
      - ZapZap
      - Solaar (Logitech stuff)
      - Libation (along with audible-cli)
      - Cimfax
      - Antigravity IDE with Antigravity Link
```

---

## 🛠️ Configured Applications

### 1. `gpu-screen-recorder`
- **Native UI Settings**: [`dot_config/gpu-screen-recorder/config_ui.tmpl`](./dot_config/gpu-screen-recorder/config_ui.tmpl)
  - Configures 60 FPS, hardware HEVC / H.265 encoding, Opus audio, MP4 container, and dynamic home paths (`{{ .chezmoi.homeDir }}/Videos`).
- **Flatpak Settings**: [`dot_var/app/com.dec05eba.gpu_screen_recorder/config/gpu-screen-recorder/config.tmpl`](./dot_var/app/com.dec05eba.gpu_screen_recorder/config/gpu-screen-recorder/config.tmpl)
- **Virtual Silent Sink**: [`dot_config/pipewire/pipewire.conf.d/10-silent-sink.conf`](./dot_config/pipewire/pipewire.conf.d/10-silent-sink.conf)
- **Auto-Silence & Title Renaming**:
  - Daemon: `dot_local/bin/executable_gsr-audio-auto-silence.sh`
  - Renamer: `dot_local/bin/executable_gsr-rename-latest.py`
  - Service: `dot_config/systemd/user/gsr-audio-silence.service`

### 2. `yt-dlp` (with Deno and FFmpeg)
- **Config**: [`dot_config/yt-dlp/config.tmpl`](./dot_config/yt-dlp/config.tmpl)
  - Best video & audio merging into MP4 using FFmpeg (`--merge-output-format mp4`).
  - Deno integration for YouTube signature and JavaScript challenge solving (`--js-runtimes deno`, `--remote-components ejs:github`).
  - Metadata and thumbnail embedding (`--add-metadata`, `--embed-thumbnail`).
  - Download archive tracking (`~/.config/yt-dlp/archive.txt`) and Firefox cookie integration.
- **Playlists**: [`dot_config/yt-dlp/playlists.txt`](./dot_config/yt-dlp/playlists.txt)
- **Shell PATH Integration**: [`dot_profile`](./dot_profile) and [`dot_bashrc`](./dot_bashrc) ensure `~/.local/bin`, `~/.deno/bin`, and Homebrew / Linuxbrew (`/home/linuxbrew/.linuxbrew/bin`, `/opt/homebrew/bin`) are always exported.

### 3. `iptvnator`
- **Stalker Source Database Seed**: [`dot_iptvnator/databases/iptvnator.db`](./dot_iptvnator/databases/iptvnator.db)
  - Pre-seeded SQLite database configured with the `b4u` Stalker portal (`http://portal.elite4k.co/stalker_portal/server/load.php`) and MAC address `00:1A:79:35:36:33`.
- **Idempotent Setup Script**: [`run_once_after_setup-iptvnator.py`](./run_once_after_setup-iptvnator.py)
  - Runs automatically on `chezmoi apply` to ensure the stalker portal entry is idempotently registered even if the app has already initialized its database.
- **Player & Window Defaults**: [`dot_config/IPTVnator/config.json`](./dot_config/IPTVnator/config.json)

---

## 🚀 Applying with Chezmoi

```bash
# Apply dotfiles to the current user environment
chezmoi apply --source ~/Workspace/home-setup/nano
```
