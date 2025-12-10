#!/usr/bin/env bash
# Configure USB capture helper: detect your capture device and write environment file and udev rule
# Usage: sudo ./configure.sh
set -euo pipefail
BASEDIR=$(cd "$(dirname "$0")/.." && pwd)

echo "Detecting USB capture video devices..."
if ! command -v udevadm >/dev/null 2>&1; then
echo "udevadm is required. Please install systemd/udev utilities."; exit 1; fi

# Find video devices from /dev/video* and match vendor (if any). If only one video device, prefer that.
VIDEO_DEV=/dev/video0
if [ -e /dev/video0 ]; then
  VIDEO_DEV=/dev/video0
else
  VIDEO_DEV=$(ls -1 /dev/video* 2>/dev/null | head -n1 || true)
fi

if [ -z "$VIDEO_DEV" ]; then
  echo "No /dev/video* device found. Plug in your USB capture device and re-run this script."
  exit 2
fi

# Grab udev properties
UEV_PROPS=$(udevadm info -q property -n "$VIDEO_DEV")
ID_VENDOR_ID=$(echo "$UEV_PROPS" | awk -F= '/ID_VENDOR_ID=/{print $2; exit}')
ID_MODEL_ID=$(echo "$UEV_PROPS" | awk -F= '/ID_MODEL_ID=/{print $2; exit}')
ID_VENDOR=$(echo "$UEV_PROPS" | awk -F= '/ID_VENDOR=/{print $2; exit}')
ID_MODEL=$(echo "$UEV_PROPS" | awk -F= '/ID_MODEL=/{print $2; exit}')
ID_SERIAL=$(echo "$UEV_PROPS" | awk -F= '/ID_SERIAL=/{print $2; exit}')
ID_PATH=$(echo "$UEV_PROPS" | awk -F= '/ID_PATH=/{print $2; exit}')

VIDPID="${ID_VENDOR_ID}:${ID_MODEL_ID}"

# See if /dev/v4l/by-id exists and find the matching symlink
BY_ID=""
if [ -d /dev/v4l/by-id ]; then
  # Try to match part of vendor/model
  BY_ID=$(ls -1 /dev/v4l/by-id/* 2>/dev/null | grep -i "${ID_VENDOR:-}\\|${ID_MODEL:-}" | head -n1 || true)
fi

BY_PATH=""
if [ -d /dev/v4l/by-path ]; then
  BY_PATH=$(readlink -f /dev/v4l/by-path/* 2>/dev/null | grep -F "$VIDEO_DEV" -m1 | head -n1 || true)
fi

# If we couldn't find a nicer path, fallback to direct device node
if [ -n "$BY_ID" ]; then
  PERSISTENT_PATH="$BY_ID"
elif [ -n "$BY_PATH" ]; then
  PERSISTENT_PATH="$BY_PATH"
else
  PERSISTENT_PATH="$VIDEO_DEV"
fi

cat <<EOF
Detected:
  Physical device node: $VIDEO_DEV
  Vendor ID/Product ID: $VIDPID
  Vendor: ${ID_VENDOR:-N/A}
  Model: ${ID_MODEL:-N/A}
  Serial (if any): ${ID_SERIAL:-N/A}
  Persistent path chosen: $PERSISTENT_PATH

EOF

# Offer to write environment file to /etc/default/usb-capture (used by systemd units)
ENVFILE=/etc/default/usb-capture
sudo tee "$ENVFILE" >/dev/null <<EOL
# USB capture environment file
USB_CAPTURE_VIDEO="$PERSISTENT_PATH"
USB_CAPTURE_VIDPID="$VIDPID"
USB_CAPTURE_VENDOR="$ID_VENDOR"
USB_CAPTURE_MODEL="$ID_MODEL"
USB_CAPTURE_SERIAL="$ID_SERIAL"
EOL
sudo chmod 644 "$ENVFILE"

# Offer to create a udev rule to disable autosuspend and create a symlink for the device (if by-id not present)
if [ -z "$BY_ID" ]; then
  echo "
No /dev/v4l/by-id entry found. Creating a udev rule to create /dev/usb-capture0 symlink and disable autosuspend for VID:PID $VIDPID"
  UDEVRULE=/etc/udev/rules.d/99-usb-capture.rules
  sudo tee "$UDEVRULE" >/dev/null <<RULE
# udev rule for USB capture device
ACTION=="add|change", SUBSYSTEM=="video4linux", ATTRS{idVendor}=="${ID_VENDOR_ID}", ATTRS{idProduct}=="${ID_MODEL_ID}", SYMLINK+="usb-capture0"
ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="${ID_VENDOR_ID}", ATTR{idProduct}=="${ID_MODEL_ID}", TEST=="/sys/bus/usb/devices/%k/power/control", ATTR{power/control}:="on"
RULE
  sudo udevadm control --reload-rules || true
  sudo udevadm trigger || true
fi

echo "Note: this configure script only writes /etc/default/usb-capture and a udev rule (if applicable). Run ./scripts/install.sh to generate and enable systemd services."

echo "Configuration complete. If the device ever moves to a different port, you can re-run this script to refresh the environment file."

exit 0
