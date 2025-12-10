#!/usr/bin/env bash
# Check for dependencies
set -euo pipefail
for cmd in gcc ffmpeg v4l2-ctl uvcdynctrl modprobe systemctl; do
  if ! command -v $cmd >/dev/null 2>&1; then
    echo "Missing command: $cmd"
  else
    echo "$cmd: OK"
  fi
done

echo "Check kernel module: v4l2loopback"
if lsmod | grep -q v4l2loopback; then
  echo "v4l2loopback loaded"
else
  echo "v4l2loopback not loaded"
fi

echo "Check drivers for video devices:"
for d in /dev/video*; do
  if [ -e "$d" ]; then
    echo "Device: $d"
    udevadm info -q property -n "$d" | grep -E 'ID_VENDOR|ID_MODEL|ID_PATH|ID_USB' || true
  fi
done
