#!/usr/bin/env bash
set -euo pipefail
BASEDIR=$(cd "$(dirname "$0")/.." && pwd)

if [ -f "$BASEDIR/scripts/usbreset" ]; then
  rm -f "$BASEDIR/scripts/usbreset"
fi

# Remove udev rules
sudo rm -f /etc/udev/rules.d/99-ugreen.rules || true
sudo rm -f /etc/udev/rules.d/99-usb-capture.rules || true
sudo udevadm control --reload-rules || true

# Remove systemd
sudo systemctl disable --now usb-capture-monitor.service usb-capture-ffmpeg.service || true
sudo rm -f /etc/systemd/system/usb-capture-monitor.service /etc/systemd/system/usb-capture-ffmpeg.service || true
sudo systemctl daemon-reload || true
sudo rm -f /etc/default/ugreen-fix || true
sudo rm -f /etc/default/usb-capture || true
sudo systemctl daemon-reload || true

echo "Uninstall finished."