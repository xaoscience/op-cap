# op-cap — Linux USB Capture Card Optimization

Stabilize high-throughput USB capture devices for OBS on Linux. Provides auto-reconnect, USB reset, v4l2loopback feed isolation, and performance optimizations.

## Features

- **v4l2loopback isolation** — FFmpeg feeds capture to `/dev/video10`, preventing OBS crashes from driver issues
- **Auto-reconnect** — Monitors device and restarts feed on disconnect
- **USB reset & driver rebind** — Recovers from device hangs without reboot
- **Performance optimizations** — Disables USB autosuspend, optimizes power settings
- **HDR passthrough** — Configurable color handling modes
- **Optional overlay** — Add logo/watermark from URL or file
- **Format auto-detection** — Detects best resolution/fps during install

## Quick Start

```bash
make build
make install   # Interactive — select your capture device
```

Check status:
```bash
sudo systemctl status usb-capture-ffmpeg.service usb-capture-monitor.service
```

Uninstall:
```bash
make uninstall
```

## Configuration

All settings in `/etc/default/usb-capture`:

| Variable | Description | Default |
|----------|-------------|---------|
| `USB_CAPTURE_VIDEO` | Device path (auto-detected) | `/dev/v4l/by-id/...` |
| `USB_CAPTURE_RES` | Resolution | `3840x2160` |
| `USB_CAPTURE_FPS` | Framerate | `30` |
| `USB_CAPTURE_FORMAT` | Input format | `NV12` |
| `USB_CAPTURE_HDR_MODE` | HDR handling (see below) | `2` |
| `USB_CAPTURE_OVERLAY_URL` | Overlay image URL | *(empty)* |
| `USB_CAPTURE_OVERLAY_FILE` | Overlay image path | *(empty)* |
| `USB_CAPTURE_OVERLAY_X/Y` | Overlay position | `10` |
| `USB_CAPTURE_OVERLAY_SCALE` | Overlay width (px) | `500` |
| `USB_CAPTURE_DELOGO_ENABLE` | Enable delogo filter | `0` |

### HDR Modes

| Mode | Behavior |
|------|----------|
| `0` | Auto — trust device (may delay startup) |
| `1` | Force HDR interpretation + tonemap to SDR |
| `2` | Force HDR passthrough (fastest startup) **← default** |
| `3` | Force SDR interpretation |

Most devices auto-handle HDR internally. Mode 2 provides fastest startup without color issues.

## OBS Setup

1. Add **Video Capture Device** source
2. Select `/dev/video10` (labeled "USB_Capture_Loop")
3. Resolution/FPS auto-detected

If device not visible:
```bash
sudo modprobe -r v4l2loopback && sudo modprobe v4l2loopback video_nr=10 card_label="USB_Capture_Loop" exclusive_caps=1
```

## Scripts

| Script | Purpose |
|--------|---------|
| `install.sh` | Interactive install with format detection |
| `uninstall.sh` | Remove services and config |
| `optimize_device.sh` | Apply USB performance settings |
| `auto_reconnect.sh` | Monitor and restart on disconnect |
| `repair.sh` | Full recovery (reset, rebind, restart) |
| `usb_reset.sh` | Reset USB device by VID:PID |
| `detect_device.sh` | Show device info |
| `pick_delogo.sh` | Visual delogo coordinate picker |

## Troubleshooting

**Device disconnects under load:**
```bash
# Check USB errors
dmesg | grep -iE 'usb|xhci' | tail -20

# Verify autosuspend disabled
cat /sys/bus/usb/devices/*/power/control
```

**Service not starting:**
```bash
journalctl -u usb-capture-ffmpeg.service -f
```

**Loopback device not created:**
```bash
sudo modprobe v4l2loopback video_nr=10 exclusive_caps=1
ls /dev/video10
```

## Requirements

- `ffmpeg`, `v4l-utils`, `v4l2loopback-dkms`
- Optional: `uhubctl` (hub power control), `slop` (visual picker)

```bash
sudo apt install ffmpeg v4l-utils v4l2loopback-dkms
```