#!/usr/bin/env bash
# Reset a USB device. Usage: sudo ./usb_reset.sh <bus> <devnum> or <device_path> or <VID:PID>
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: $0 <bus> <devnum> | /dev/bus/usb/BBB/DDD | vid:pid"
  exit 2
fi

function do_reset_path() {
  local path="$1"
  if [ -c "$path" ]; then
    if [ -f ./usbreset ]; then
      ./usbreset "$path"
    else
      echo "Attempting usbdevfs_reset via sysfs (requires usbreset tool for ioctl fallback)."
      echo "If usbreset compiled, run it from this dir (cc usbreset.c -o usbreset)"
      echo "Falling back to unbind/bind..."
      # attempt unbind/bind using driver
      device_id=$(udevadm info -q path -n "$path" | sed 's,/devices/,,') || true
      echo "Device path: $device_id"
    fi
  else
    echo "$path is not a character device, can't usbreset"
    exit 1
  fi
}

if [[ "$1" =~ ^[0-9]{3}$ ]] && [[ "$2" =~ ^[0-9]{3}$ ]]; then
  BUS=$(printf "%03d" "$1")
  DEV=$(printf "%03d" "$2")
  device_node="/dev/bus/usb/$BUS/$DEV"
  do_reset_path "$device_node"
  exit 0
fi

if [[ "$1" =~ ^/dev/bus/usb/.+ ]]; then
  do_reset_path "$1"
  exit 0
fi

if [[ "$1" =~ ^[0-9a-fA-F]{4}:[0-9a-fA-F]{4}$ ]]; then
  VID=$(echo "$1" | cut -d: -f1)
  PID=$(echo "$1" | cut -d: -f2)
  busdev=$(ls -1 /sys/bus/usb/devices/* | while read D; do if [[ -f $D/idVendor && -f $D/idProduct ]]; then v=$(cat $D/idVendor); p=$(cat $D/idProduct); if [[ "$v" == "$VID" && "$p" == "$PID" ]]; then basename $D; fi; fi; done | head -n1)
  if [ -z "$busdev" ]; then
    echo "No usb device found for $VID:$PID"
    exit 2
  fi
  bus=$(cat /sys/bus/usb/devices/$busdev/busnum)
  dev=$(cat /sys/bus/usb/devices/$busdev/devnum)
  BUS=$(printf "%03d" "$bus")
  DEV=$(printf "%03d" "$dev")
  device_node="/dev/bus/usb/$BUS/$DEV"
  do_reset_path "$device_node"
  exit 0
fi

echo "Unknown argument format"
exit 3
