#!/usr/bin/env bash
# Install sudoers rule for OBS crash recovery without password prompts
# This allows auto_reconnect.sh and USB recovery scripts to run with sudo during crash recovery

set -euo pipefail

SUDOERS_FILE="/home/jnxlr/PRO/WEB/CST/op-cap/etc/sudoers.d/obs-safe-launch"
INSTALL_PATH="/etc/sudoers.d/obs-safe-launch"

echo "Installing sudoers rule for passwordless crash recovery..."
echo "This allows the following scripts to run with sudo without password:"
echo "  - auto_reconnect.sh (USB device monitoring)"
echo "  - usb_reset.sh (USB hardware reset)"
echo "  - repair.sh (recovery operations)"
echo "  - systemctl commands for ffmpeg service"
echo ""
echo "Security: Limited to specific scripts in your project directory only."
echo ""

# Validate syntax again
if ! sudo visudo -c -f "$SUDOERS_FILE"; then
  echo "ERROR: Sudoers file has syntax errors. Aborting."
  exit 1
fi

# Install
sudo cp "$SUDOERS_FILE" "$INSTALL_PATH"
sudo chmod 0440 "$INSTALL_PATH"
sudo chown root:root "$INSTALL_PATH"

echo ""
echo "✓ Sudoers rule installed successfully: $INSTALL_PATH"
echo ""
echo "Test it with:"
echo "  sudo -n /home/jnxlr/PRO/WEB/CST/op-cap/scripts/auto_reconnect.sh --help"
echo ""
echo "To uninstall:"
echo "  sudo rm $INSTALL_PATH"
