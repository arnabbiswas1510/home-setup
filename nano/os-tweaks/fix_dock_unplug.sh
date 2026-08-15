#!/usr/bin/env bash
# Script to resolve USB-C / Thunderbolt Dock Unplug Freeze & Beeping on Lenovo ThinkPad X1 Nano Gen 3
set -e

echo "=== Applying Dock Unplug Resilience Fixes ==="

# 1. Disable Intel GPU Panel Self Refresh (PSR) to prevent DRM / KWin Wayland GPU hangs
echo "[1/4] Configuring i915 / xe graphics parameters (disabling PSR)..."
cat << 'EOF' | sudo tee /etc/modprobe.d/i915-psr.conf > /dev/null
# Disable Panel Self Refresh (PSR) on Intel Iris Xe / Raptor Lake graphics
# Prevents GPU hang and EGL surface allocation failure when disconnecting USB-C/Thunderbolt displays
options i915 enable_psr=0
options xe enable_psr=0
EOF

# 2. Blacklist PC Speaker module to stop kernel beeping
echo "[2/4] Blacklisting pcspkr kernel module..."
cat << 'EOF' | sudo tee /etc/modprobe.d/nobeep.conf > /dev/null
# Disable PC speaker system beeps
blacklist pcspkr
blacklist snd_pcsp
EOF

# 3. Fix PAM smartcard / sssd configuration for kscreenlocker
echo "[3/4] Fixing PAM authentication configuration..."
if dpkg -l | grep -q libpam-sss; then
    echo "  libpam-sss is already installed."
else
    echo "  Installing libpam-sss to fix missing pam_sss.so module in PAM..."
    sudo apt-get update -qq && sudo apt-get install -y libpam-sss || {
        echo "  apt install failed, setting gdm-smartcard alternative to pkcs11 fallback..."
        sudo update-alternatives --set gdm-smartcard /etc/pam.d/gdm-smartcard-pkcs11-exclusive || true
    }
fi

# 4. Update initramfs so boot early stage loads these module parameters
echo "[4/4] Updating initramfs..."
sudo update-initramfs -u

echo ""
echo "=== Software Fixes Applied Successfully! ==="
echo ""
echo "IMPORTANT HARDWARE STEP (To stop ThinkPad BIOS Beep):"
echo "1. Reboot your laptop and press F1 at the Lenovo logo to enter BIOS."
echo "2. Navigate to Config -> Power."
echo "3. Set 'Power Control Beep' to Disabled."
echo "4. (Optional) Navigate to Config -> Beep and Alarm and ensure Power Beep is Disabled."
echo "5. Press F10 to Save and Exit."
