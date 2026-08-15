#!/usr/bin/env bash
# Script to fix DisplayLink EVDI Hot-Unplug Freeze under Wayland for Lenovo ThinkPad Hybrid Dock
# and Sync Multi-Monitor Layout to SDDM Login Screen when Laptop Lid is Closed.
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root (e.g. sudo ./apply_evdi_wayland_fix.sh)"
  exit 1
fi

echo "=== Applying DisplayLink EVDI Wayland Hot-Unplug & SDDM Display Fixes ==="

# 1. Update evdi.conf to use 2 virtual display devices (matching physical dock monitors)
echo "[1/4] Setting EVDI virtual device count to 2..."
cat << 'EOF' > /etc/modprobe.d/evdi.conf
softdep evdi pre: drm_display_helper drm_ttm_helper i915 xe 
options evdi initial_device_count=2
EOF

# 2. Create udev rule to gracefully restart displaylink-driver on dock unplug
echo "[2/4] Creating udev rule for Lenovo ThinkPad Hybrid Dock (17e9:6015)..."
cat << 'EOF' > /etc/udev/rules.d/99-displaylink-hotplug.rules
# Gracefully reset DisplayLink driver on Lenovo ThinkPad Hybrid Dock unplug to prevent KWin DRM pageflip hangs
ACTION=="remove", SUBSYSTEM=="usb", ENV{ID_VENDOR_ID}=="17e9", ENV{ID_MODEL_ID}=="6015", RUN+="/usr/bin/systemctl restart --no-block displaylink-driver"
EOF

# 3. Reload udev rules and update initramfs
echo "[3/4] Reloading udev rules and updating initramfs..."
udevadm control --reload-rules && udevadm trigger
update-initramfs -u

# 4. Configure KWin Wayland DRM environment variables for EVDI hot-plug stability
echo "[4/5] Setting KWin DRM environment variables (disabling format modifiers & ordering cards)..."
mkdir -p /etc/environment.d
cat << 'EOF' > /etc/environment.d/evdi.conf
KWIN_DRM_USE_MODIFIER=0
KWIN_DRM_DEVICES=/dev/dri/card0:/dev/dri/card1:/dev/dri/card2
EOF

grep -q "KWIN_DRM_USE_MODIFIER" /etc/environment || cat << 'EOF' >> /etc/environment
KWIN_DRM_USE_MODIFIER=0
KWIN_DRM_DEVICES=/dev/dri/card0:/dev/dri/card1:/dev/dri/card2
EOF

# 5. Copy user's kwinoutputconfig.json to SDDM so SDDM uses external monitors when lid is closed
echo "[5/5] Syncing user display configuration (lid-closed monitor layout) to SDDM login screen..."
mkdir -p /var/lib/sddm/.config
if [ -f /home/pom/.config/kwinoutputconfig.json ]; then
  cp /home/pom/.config/kwinoutputconfig.json /var/lib/sddm/.config/kwinoutputconfig.json
  chown -R sddm:sddm /var/lib/sddm/.config
  echo "  Display configuration successfully synced to SDDM."
else
  echo "  Warning: /home/pom/.config/kwinoutputconfig.json not found."
fi

echo ""
echo "=== All Fixes Applied Successfully! ==="
echo "Please reboot your system once to activate the updated evdi configuration, KWin Wayland environment, and SDDM layout."
