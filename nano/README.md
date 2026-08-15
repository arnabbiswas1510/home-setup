# Nano Machine Setup (`nano`)

Configuration, dotfiles, hardware fixes, system configuration backups, and automation for **Lenovo ThinkPad X1 Nano Gen 3** running **Debian 13 (Trixie)** with **KDE Plasma 6 (Wayland)**.

---

## 📁 Folder Structure

```text
nano/
├── README.md                                    # Machine documentation & runbook
├── .chezmoidata/
│   └── hosts.toml                               # APT packages, repos, and service definitions for Nano
├── run_onchange_before_00-install-packages.sh.tmpl # Automated APT & Flatpak installer
├── run_onchange_after_10-setup-services.sh.tmpl   # Automated Systemd services setup
├── run_onchange_after_20-install-user-tools.sh.tmpl# yt-dlp & Deno tool installer
├── dot_bashrc                                   # Shell environment (~/.bashrc)
├── dot_profile                                  # User profile (~/.profile)
├── dot_config/
│   ├── IPTVnator/                               # IPTV player configuration
│   ├── dolphinrc                                # Dolphin file manager preferences & bookmarks
│   ├── kdeglobals                               # KDE Plasma system appearance & colors
│   ├── kglobalshortcutsrc                       # Global desktop shortcuts
│   ├── konsolerc                                # Konsole terminal configuration
│   ├── kwinrc                                   # KWin window management & tiling rules
│   ├── mimeapps.list                            # Default application associations
│   ├── qimgv/                                   # qimgv image viewer settings
│   ├── spectaclerc                              # Spectacle screenshot configuration
│   └── yt-dlp/                                  # yt-dlp global settings & format rules
├── dot_gemini/
│   └── config/mcp_config.json                   # Antigravity MCP Servers (Home Assistant, Garmin)
├── dot_local/
│   ├── bin/
│   │   ├── executable_clean-cache.sh            # Local cache cleanup utility
│   │   ├── executable_iptvnator                # Wayland/X11 launcher wrapper
│   │   ├── executable_libation                  # Libation launcher wrapper
│   │   └── executable_yt-autodownload           # YouTube playlist sync script
│   └── share/
│       ├── konsole/MyProfile.profile            # Custom Konsole profile
│       └── user-places.xbel                     # Dolphin quick-access bookmarks & NAS shares
├── etc/                                         # Direct backups of modified system configs in /etc
│   ├── fstab                                    # /etc/fstab (btrfs root & CIFS NAS automounts)
│   ├── environment                              # /etc/environment (KWin DRM environment)
│   ├── environment.d/evdi.conf                  # /etc/environment.d/evdi.conf
│   ├── default/grub.d/99-fastboot.cfg           # Fast boot GRUB timeout configuration
│   ├── modprobe.d/
│   │   ├── evdi.conf                            # EVDI dual-display configuration
│   │   ├── i915-psr.conf                        # Intel GPU PSR disable
│   │   └── nobeep.conf                          # PC speaker blacklisting
│   ├── modules-load.d/evdi.conf                 # Early kernel module load configuration
│   ├── udev/rules.d/99-displaylink-hotplug.rules# DisplayLink dock unplug udev rule
│   ├── sysctl.d/50-kde-inotify-survey-...conf   # Inotify instances limit
│   ├── samba/credentials-192.168.1.50.example   # Samba NAS credentials template
│   └── apt/sources.list.d/                      # Third-party APT repositories
├── os-tweaks/
│   ├── apply_evdi_wayland_fix.sh                # DisplayLink EVDI hot-unplug fix & SDDM monitor sync
│   ├── fix_dock_unplug.sh                       # Intel GPU PSR disable & dock unplug resilience
│   ├── optimize_boot.sh                         # GRUB fastboot & CIFS automount timeout optimization
│   └── setup_nas_mounts.sh                      # /etc/fstab CIFS mount setup for DietPi NAS
└── scripts/
    ├── install_ohmyzsh.sh                       # Zsh & Oh-My-Zsh unattended setup
    ├── install_plex.sh                          # Plex Desktop flatpak installation
    └── install_syncthing.sh                     # Syncthing user service installer
```

---

## 🚀 Quick Setup with chezmoi

Apply configurations directly to the system using `chezmoi`:

```bash
# Apply dotfiles and system packages for Nano
chezmoi apply --source ~/workspace/home-setup/nano
```

---

## 🔧 Hardware & OS Tweaks (`os-tweaks/`)

### 1. DisplayLink & Wayland Dock Stability (`apply_evdi_wayland_fix.sh`)
- Configures EVDI virtual display count to 2 matching the physical dock monitors.
- Adds udev rules to reset `displaylink-driver` on dock unplug.
- Sets `KWIN_DRM_USE_MODIFIER=0` and device paths for DRM stability.
- Syncs `kwinoutputconfig.json` to SDDM for lid-closed multi-monitor login.

```bash
sudo ./os-tweaks/apply_evdi_wayland_fix.sh
```

### 2. Dock Unplug Freeze & BIOS Beep Fix (`fix_dock_unplug.sh`)
- Disables Intel GPU Panel Self Refresh (`enable_psr=0` for `i915` and `xe`).
- Blacklists `pcspkr` and `snd_pcsp`.
- Updates initramfs for early boot persistence.

```bash
sudo ./os-tweaks/fix_dock_unplug.sh
```

### 3. Fast Boot Optimization (`optimize_boot.sh`)
- Configures instant GRUB boot (`GRUB_TIMEOUT=0`).
- Disables `NetworkManager-wait-online.service`.
- Adds `x-systemd.idle-timeout=60,x-systemd.mount-timeout=5s,noauto` to `/etc/fstab` CIFS shares.

```bash
sudo ./os-tweaks/optimize_boot.sh
```

### 4. NAS Mounts Auto-Configuration (`setup_nas_mounts.sh`)
- Installs `cifs-utils`.
- Mounts DietPi Samba shares (`/mnt/dietpi`, `/mnt/dietpi-home`, `/mnt/books`, `/mnt/media1`, `/mnt/media2`, `/mnt/tvShows`, `/mnt/scratch`) with credentials and systemd automount.

```bash
sudo ./os-tweaks/setup_nas_mounts.sh
```
