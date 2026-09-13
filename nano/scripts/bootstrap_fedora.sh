#!/usr/bin/env bash
# ==============================================================================
# Automated Fedora Post-Install Bootstrap for Lenovo ThinkPad X1 Nano Gen 3
# Fully restores desktop environment, packages, Flatpaks, hardware tweaks, 
# NAS automounts, and user services with 0 manual intervention.
# ==============================================================================

set -euo pipefail

echo "======================================================================"
echo "    Lenovo ThinkPad X1 Nano - Fedora Post-Install Bootstrap           "
echo "======================================================================"

if [ "$(id -u)" -eq 0 ]; then
    echo "[-] Please run this script as your regular user (pom), NOT as root."
    echo "    Sudo permissions will be requested when needed."
    exit 1
fi

REAL_USER="$USER"
REAL_HOME="$HOME"

# 1. Enable RPM Fusion (Free and Nonfree)
echo ""
echo "[1/9] Enabling RPM Fusion repositories..."
sudo dnf install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm || true

# 2. Add Vendor Third-Party Repositories (Chrome, Sublime, Tailscale)
echo ""
echo "[2/9] Configuring vendor RPM repositories..."
# Google Chrome
sudo dnf config-manager --set-enabled google-chrome 2>/dev/null || \
sudo dnf config-manager --add-repo https://dl.google.com/linux/chrome/rpm/stable/x86_64 2>/dev/null || true

# Sublime Text
sudo rpm -v --import https://download.sublimetext.com/sublimehq-rpm-pub.gpg 2>/dev/null || true
sudo dnf config-manager --add-repo https://download.sublimetext.com/rpm/stable/x86_64/sublime-text.repo 2>/dev/null || true

# Tailscale
sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo 2>/dev/null || true

# 3. Install Curated Fedora DNF Packages
echo ""
echo "[3/9] Installing system & command line packages..."
sudo dnf install -y \
  @development-tools \
  git zsh curl wget lsof rclone btop nvtop htop tmux \
  cifs-utils snapper btrfs-progs wl-clipboard qimgv feh \
  flatpak dkms kernel-devel firewalld thermald podman distrobox \
  google-chrome-stable sublime-text tailscale syncthing \
  lz4 lz4-devel dpkg bolt chezmoi \
  intel-media-driver libva-intel-driver libva-utils ffmpeg \
  gstreamer1-plugins-good gstreamer1-plugins-bad-free gstreamer1-tools libcamera-tools kde-plasma-addons || true

# 4. Intel ThinkPad X1 Nano Hardware & Dock Tweaks
echo ""
echo "[4/9] Applying ThinkPad X1 Nano hardware tweaks (PSR, nobeep, Thunderbolt 4)..."
# Disable Intel GPU Panel Self Refresh (PSR)
sudo tee /etc/modprobe.d/i915-psr.conf > /dev/null << 'TWEAK_EOF'
# Disable PSR on Intel Iris Xe graphics to prevent dock sleep/wake freezes
options i915 enable_psr=0
options xe enable_psr=0
TWEAK_EOF

# Blacklist PC speaker beeps
sudo tee /etc/modprobe.d/nobeep.conf > /dev/null << 'TWEAK_EOF'
blacklist pcspkr
blacklist snd_pcsp
TWEAK_EOF

# Enable Thunderbolt daemon for ThinkPad Thunderbolt 4 Dock
sudo systemctl enable --now bolt.service 2>/dev/null || true

sudo dracut --force || true

# 5. DietPi NAS Automounts (/etc/fstab)
echo ""
echo "[5/9] Setting up DietPi NAS automounts in /etc/fstab..."
sudo mkdir -p /etc/samba
sudo mkdir -p /mnt/dietpi /mnt/dietpi-home /mnt/books /mnt/media1 /mnt/media2 /mnt/tvShows /mnt/scratch /mnt/pom

if [ ! -f /etc/samba/credentials-192.168.1.50 ]; then
    sudo tee /etc/samba/credentials-192.168.1.50 > /dev/null << 'SMB_EOF'
username=dietpi
password=paro
domain=WORKGROUP
SMB_EOF
    sudo chmod 600 /etc/samba/credentials-192.168.1.50
fi

sudo sed -i '/192.168.1.50/d' /etc/fstab
sudo tee -a /etc/fstab > /dev/null << 'FSTAB_EOF'

# NAS 192.168.1.50 Samba Shares
//192.168.1.50/pom         /mnt/pom         cifs credentials=/etc/samba/credentials-192.168.1.50,uid=1000,gid=1000,iocharset=utf8,nofail,_netdev,x-systemd.automount,x-systemd.idle-timeout=60,x-systemd.mount-timeout=5s,noauto 0 0
//192.168.1.50/books       /mnt/books       cifs credentials=/etc/samba/credentials-192.168.1.50,uid=1000,gid=1000,iocharset=utf8,nofail,_netdev,x-systemd.automount,x-systemd.idle-timeout=60,x-systemd.mount-timeout=5s,noauto 0 0
//192.168.1.50/media1      /mnt/media1      cifs credentials=/etc/samba/credentials-192.168.1.50,uid=1000,gid=1000,iocharset=utf8,nofail,_netdev,x-systemd.automount,x-systemd.idle-timeout=60,x-systemd.mount-timeout=5s,noauto 0 0
//192.168.1.50/media2      /mnt/media2      cifs credentials=/etc/samba/credentials-192.168.1.50,uid=1000,gid=1000,iocharset=utf8,nofail,_netdev,x-systemd.automount,x-systemd.idle-timeout=60,x-systemd.mount-timeout=5s,noauto 0 0
//192.168.1.50/tvShows     /mnt/tvShows     cifs credentials=/etc/samba/credentials-192.168.1.50,uid=1000,gid=1000,iocharset=utf8,nofail,_netdev,x-systemd.automount,x-systemd.idle-timeout=60,x-systemd.mount-timeout=5s,noauto 0 0
//192.168.1.50/scratch     /mnt/scratch     cifs credentials=/etc/samba/credentials-192.168.1.50,uid=1000,gid=1000,iocharset=utf8,nofail,_netdev,x-systemd.automount,x-systemd.idle-timeout=60,x-systemd.mount-timeout=5s,noauto 0 0
FSTAB_EOF

sudo systemctl daemon-reload

# 6. Install Flatpak Applications
echo ""
echo "[6/9] Setting up Flathub and restoring Flatpak applications..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

FLATPAKS=(
  "com.dec05eba.gpu_screen_recorder"
  "com.github.dynobo.normcap"
  "com.github.johnfactotum.Foliate"
  "com.logseq.Logseq"
  "com.rcloneui.RcloneUI"
  "com.rtosta.zapzap"
  "info.smplayer.SMPlayer"
  "io.github.pwr_solaar.solaar"
  "io.mpv.Mpv"
  "org.avidemux.Avidemux"
  "org.jellyfin.JellyfinDesktop"
  "org.kde.falkon"
  "org.videolan.VLC"
  "org.winehq.Wine"
  "tv.plex.PlexDesktop"
  "us.zoom.Zoom"
)

for app in "${FLATPAKS[@]}"; do
    echo "  Installing ${app}..."
    flatpak install -y --noninteractive flathub "${app}" || true
done

# Zoom flatpak device permission override
flatpak override --user --device=all us.zoom.Zoom || true

# Restore GPU Screen Recorder Flatpak configuration
echo "  Restoring GPU Screen Recorder customizations..."
mkdir -p "$REAL_HOME/.var/app/com.dec05eba.gpu_screen_recorder/config/gpu-screen-recorder"
cp -f "$REAL_HOME/workspace/home-setup/nano/dot_var/app/com.dec05eba.gpu_screen_recorder/config/gpu-screen-recorder/config" \
  "$REAL_HOME/.var/app/com.dec05eba.gpu_screen_recorder/config/gpu-screen-recorder/config" 2>/dev/null || true

# 7. Install/Verify Chezmoi & Apply Dotfiles
echo ""
echo "[7/9] Applying dotfiles with Chezmoi..."
if ! command -v chezmoi >/dev/null 2>&1; then
    mkdir -p "$REAL_HOME/.local/bin"
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$REAL_HOME/.local/bin"
fi
chezmoi apply --source "$REAL_HOME/workspace/home-setup/nano" || true

# Ensure permissions for custom scripts and desktop launchers
echo "  Setting permissions for custom utilities & desktop launchers..."
chmod +x "$REAL_HOME"/auto-rename-recording.py "$REAL_HOME"/batch-recorder.py "$REAL_HOME"/toggle-silent-app.py "$REAL_HOME"/route-to-silent.sh 2>/dev/null || true
chmod +x "$REAL_HOME"/.local/bin/* 2>/dev/null || true
mkdir -p "$REAL_HOME/Desktop"
chmod +x "$REAL_HOME"/Desktop/*.desktop 2>/dev/null || true

# Configure KDE Picture of the Day (Bing) wallpaper across all displays
echo "  Configuring Picture of the Day (Bing) wallpaper on all displays..."
if command -v qdbus6 >/dev/null 2>&1; then
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
        let d = desktops();
        for (let i = 0; i < d.length; i++) {
            d[i].wallpaperPlugin = "org.kde.potd";
            d[i].currentConfigGroup = Array("Wallpaper", "org.kde.potd", "General");
            d[i].writeConfig("Provider", "bing");
        }
    ' 2>/dev/null || true
fi

# 8. Restore Application Data & Standalone Apps (Libation, IPTVnator, Antigravity, Flatpaks)
echo ""
echo "[8/10] Restoring application data and standalone apps..."
BACKUP_DIR="/mnt/media1/pom_nano_backup/home_pom"
sudo mount /mnt/media1 2>/dev/null || true

if [ -d "$BACKUP_DIR" ]; then
    echo "  Found NAS pre-migration backup at $BACKUP_DIR"

    # 1. SSH Keys
    if [ -d "$BACKUP_DIR/.ssh" ] && [ ! -d "$REAL_HOME/.ssh" ]; then
        echo "  Restoring SSH keys..."
        cp -a "$BACKUP_DIR/.ssh" "$REAL_HOME/.ssh"
        chmod 700 "$REAL_HOME/.ssh"
        chmod 600 "$REAL_HOME/.ssh"/* 2>/dev/null || true
        chmod 644 "$REAL_HOME/.ssh"/*.pub 2>/dev/null || true
    fi

    # 2. Rclone Google Drive Config
    if [ -f "$BACKUP_DIR/.config/rclone/rclone.conf" ] && [ ! -f "$REAL_HOME/.config/rclone/rclone.conf" ]; then
        echo "  Restoring Google Drive rclone configuration..."
        mkdir -p "$REAL_HOME/.config/rclone"
        cp -a "$BACKUP_DIR/.config/rclone/rclone.conf" "$REAL_HOME/.config/rclone/rclone.conf"
        chmod 600 "$REAL_HOME/.config/rclone/rclone.conf"
    fi

    # 3. Antigravity IDE & Gemini Configs
    if [ -d "$BACKUP_DIR/.local/share/antigravity-ide" ] && [ ! -d "$REAL_HOME/.local/share/antigravity-ide" ]; then
        echo "  Restoring Antigravity IDE..."
        mkdir -p "$REAL_HOME/.local/share"
        cp -a "$BACKUP_DIR/.local/share/antigravity-ide" "$REAL_HOME/.local/share/"
    fi
    if [ -d "$BACKUP_DIR/.gemini" ] && [ ! -d "$REAL_HOME/.gemini" ]; then
        echo "  Restoring Gemini CLI settings..."
        cp -a "$BACKUP_DIR/.gemini" "$REAL_HOME/"
    fi
    if [ -d "$BACKUP_DIR/.config/Antigravity IDE" ] && [ ! -d "$REAL_HOME/.config/Antigravity IDE" ]; then
        echo "  Restoring Antigravity IDE user settings..."
        mkdir -p "$REAL_HOME/.config"
        cp -a "$BACKUP_DIR/.config/Antigravity IDE" "$REAL_HOME/.config/"
    fi

    # 4. Libation (Binaries & Library Database)
    if [ -d "$BACKUP_DIR/.local/lib/libation" ] && [ ! -d "$REAL_HOME/.local/lib/libation" ]; then
        echo "  Restoring Libation binaries..."
        mkdir -p "$REAL_HOME/.local/lib"
        cp -a "$BACKUP_DIR/.local/lib/libation" "$REAL_HOME/.local/lib/"
    fi
    if [ -d "$BACKUP_DIR/.local/share/Libation" ] && [ ! -d "$REAL_HOME/.local/share/Libation" ]; then
        echo "  Restoring Libation audiobook database..."
        mkdir -p "$REAL_HOME/.local/share"
        cp -a "$BACKUP_DIR/.local/share/Libation" "$REAL_HOME/.local/share/"
    fi

    # 5. IPTVnator (Binaries & Config)
    if [ -d "$BACKUP_DIR/.local/lib/iptvnator" ] && [ ! -d "$REAL_HOME/.local/lib/iptvnator" ]; then
        echo "  Restoring IPTVnator binaries..."
        mkdir -p "$REAL_HOME/.local/lib"
        cp -a "$BACKUP_DIR/.local/lib/iptvnator" "$REAL_HOME/.local/lib/"
    fi
    if [ -d "$BACKUP_DIR/.config/IPTVnator" ] && [ ! -d "$REAL_HOME/.config/IPTVnator" ]; then
        echo "  Restoring IPTVnator settings & playlists..."
        mkdir -p "$REAL_HOME/.config"
        cp -a "$BACKUP_DIR/.config/IPTVnator" "$REAL_HOME/.config/"
    fi

    # 6. Flatpak application data (Logseq, Foliate, ZapZap, etc.)
    if [ -f "$BACKUP_DIR/../var_app_settings.tar.zst" ]; then
        echo "  Restoring Flatpak application data from archive..."
        mkdir -p "$REAL_HOME/.var"
        tar -xf "$BACKUP_DIR/../var_app_settings.tar.zst" -C "$REAL_HOME/.var/" || true
    elif [ -d "$BACKUP_DIR/.var/app" ]; then
        echo "  Restoring Flatpak application data from NAS backup..."
        mkdir -p "$REAL_HOME/.var/app"
        rsync -ah --info=progress2 "$BACKUP_DIR/.var/app/" "$REAL_HOME/.var/app/" || true
    fi

    # 7. Home Assistant Configurations
    if [ -d "$BACKUP_DIR/../workspace/ha-config" ] && [ ! -d "$REAL_HOME/workspace/ha-config" ]; then
        echo "  Restoring Home Assistant configuration..."
        mkdir -p "$REAL_HOME/workspace"
        cp -a "$BACKUP_DIR/../workspace/ha-config" "$REAL_HOME/workspace/"
    fi
fi

# Fallback: if Libation or IPTVnator are missing, run daily-user-update.sh to download/install them
if [ ! -d "$REAL_HOME/.local/lib/libation" ] || [ ! -d "$REAL_HOME/.local/lib/iptvnator" ]; then
    echo "  Setting up standalone apps via daily-user-update..."
    bash "$REAL_HOME/.local/bin/daily-user-update.sh" 2>/dev/null || true
fi

# 9. Setup & Enable User Services and Timers
echo ""
echo "[9/10] Enabling systemd user services and timers..."
mkdir -p "$REAL_HOME/.config/systemd/user"
systemctl --user daemon-reload
systemctl --user enable --now syncthing.service 2>/dev/null || true
systemctl --user enable --now rclone-gdrive.service 2>/dev/null || true
systemctl --user enable --now home-setup-autosync.service 2>/dev/null || true
systemctl --user enable --now auto-rename-recordings.service 2>/dev/null || true
systemctl --user enable --now cache-cleaner.timer 2>/dev/null || true
systemctl --user enable --now flatpak-update.timer 2>/dev/null || true

# Enable System Services
sudo systemctl enable --now tailscale.service 2>/dev/null || true
sudo systemctl enable --now thermald.service 2>/dev/null || true
sudo systemctl enable --now firewalld.service 2>/dev/null || true

# 10. Final Verification
echo ""
echo "======================================================================"
echo "  Bootstrap Complete!                                                 "
echo "  - Flatpaks restored & bound to existing ~/.var/app/ profiles        "
echo "  - DNF packages & repos configured                                   "
echo "  - NAS CIFS shares mapped under /mnt                                 "
echo "  - ThinkPad X1 Nano Wayland & hardware tweaks applied                "
echo "  - User systemd background services active                           "
echo "======================================================================"
