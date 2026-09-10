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
  lz4 lz4-devel \
  intel-media-driver libva-intel-driver libva-utils ffmpeg \
  gstreamer1-plugins-good gstreamer1-plugins-bad-free gstreamer1-tools libcamera-tools || true

# 4. Intel ThinkPad X1 Nano Hardware & Dock Tweaks
echo ""
echo "[4/9] Applying ThinkPad X1 Nano hardware tweaks (PSR, nobeep, EVDI Wayland)..."
# Disable Intel GPU Panel Self Refresh (PSR)
sudo tee /etc/modprobe.d/i915-psr.conf > /dev/null << 'TWEAK_EOF'
# Disable PSR on Intel Iris Xe graphics to prevent dock unplug freezes
options i915 enable_psr=0
options xe enable_psr=0
TWEAK_EOF

# Blacklist PC speaker beeps
sudo tee /etc/modprobe.d/nobeep.conf > /dev/null << 'TWEAK_EOF'
blacklist pcspkr
blacklist snd_pcsp
TWEAK_EOF

# DisplayLink EVDI virtual display count & KWin Wayland DRM flags
sudo tee /etc/modprobe.d/evdi.conf > /dev/null << 'TWEAK_EOF'
softdep evdi pre: drm_display_helper drm_ttm_helper i915 xe
options evdi initial_device_count=2
TWEAK_EOF

sudo mkdir -p /etc/environment.d
sudo tee /etc/environment.d/evdi.conf > /dev/null << 'TWEAK_EOF'
KWIN_DRM_USE_MODIFIER=0
KWIN_DRM_DEVICES=/dev/dri/card0:/dev/dri/card1:/dev/dri/card2
TWEAK_EOF

# Dock unplug udev rule
sudo tee /etc/udev/rules.d/99-displaylink-hotplug.rules > /dev/null << 'TWEAK_EOF'
ACTION=="remove", SUBSYSTEM=="usb", ENV{ID_VENDOR_ID}=="17e9", ENV{ID_MODEL_ID}=="6015", RUN+="/usr/bin/systemctl restart --no-block displaylink-driver"
TWEAK_EOF

sudo udevadm control --reload-rules && sudo udevadm trigger || true
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

# 7. Install/Verify Chezmoi & Apply Dotfiles
echo ""
echo "[7/9] Applying dotfiles with Chezmoi..."
if ! command -v chezmoi >/dev/null 2>&1; then
    mkdir -p "$REAL_HOME/.local/bin"
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$REAL_HOME/.local/bin"
fi
chezmoi apply --source "$REAL_HOME/workspace/home-setup/nano" || true

# 8. Setup & Enable User Services and Timers
echo ""
echo "[8/9] Enabling systemd user services and timers..."
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

# 9. Final Verification
echo ""
echo "======================================================================"
echo "  Bootstrap Complete!                                                 "
echo "  - Flatpaks restored & bound to existing ~/.var/app/ profiles        "
echo "  - DNF packages & repos configured                                   "
echo "  - NAS CIFS shares mapped under /mnt                                 "
echo "  - ThinkPad X1 Nano Wayland & hardware tweaks applied                "
echo "  - User systemd background services active                           "
echo "======================================================================"
