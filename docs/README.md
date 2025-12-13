# op-cap — Linux USB Capture Card Optimisation

Stabilise high-throughput USB capture devices for OBS on Linux. Provides auto-reconnect, USB reset, v4l2loopback feed isolation, and performance optimisations.

## Features

- **v4l2loopback isolation** — FFmpeg feeds capture to `/dev/video10`, preventing OBS crashes from driver issues
- **Auto-reconnect** — Monitors device and restarts feed on disconnect
- **USB reset & driver rebind** — Recovers from device hangs without reboot
- **Performance optimisations** — Disables USB autosuspend, optimises power settings
- **HDR passthrough** — Configurable color handling modes
- **Optional overlay** — Add logo/watermark from URL or file
- **Format auto-detection** — Detects best resolution/fps during install
- **Wayland graphics optimisation** — Fixes OBS crashes on Wayland with explicit sync and PipeWire support

## Quick Start

```bash
make build
make install   # Interactive — select your capture device
```

Optimise graphics drivers for OBS on Wayland (fixes explicit sync and PipeWire issues):
```bash
make optimise-drivers   # Auto-detect and optimise GPU driver
```

Or install with driver optimisation in one step:
```bash
make install-with-drivers
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
| `optimise_device.sh` | Apply USB performance settings |
| `optimise_drivers.sh` | **NEW:** Optimise GPU drivers for OBS on Wayland; fixes explicit sync and PipeWire crashes |
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

## Wayland Troubleshooting

**For comprehensive setup and advanced configuration, see [WAYLAND_OPTIMISATION.md](WAYLAND_OPTIMISATION.md).**

OBS on Wayland can crash due to explicit sync issues with certain GPU drivers. If you experience crashes:

### Nvidia GPU

**Symptoms:** Crashes when opening projectors, screen capture with PipeWire, or during streaming.

**Fix:**
```bash
sudo ./scripts/optimise_drivers.sh --nvidia
```

This sets `__NV_DISABLE_EXPLICIT_SYNC=1` which disables the problematic explicit sync protocol.

**Additional kernel parameter recommended:**
Add `nvidia-drm.modeset=1` to your kernel boot parameters:
1. Edit `/etc/default/grub`
2. Add to `GRUB_CMDLINE_LINUX_DEFAULT`: `nvidia-drm.modeset=1`
3. Run: `sudo update-grub`
4. Reboot

**Driver version:** Use driver 530+ for best Wayland support.
```bash
nvidia-smi  # Check current version
# If older than 530, update: sudo apt install nvidia-driver-latest-dkms
```

### AMD GPU

**Symptoms:** Screen capture hangs or stuttering with PipeWire.

**Fix:**
```bash
sudo ./scripts/optimise_drivers.sh --amd
```

Ensures AMDGPU driver is optimised for Wayland, enables color block compression.

### Intel GPU

**Symptoms:** PipeWire screen capture issues or poor performance.

**Fix:**
```bash
sudo ./scripts/optimise_drivers.sh --intel
```

Optimises i915 driver for VA-API hardware acceleration on Wayland.

### Verify PipeWire Configuration

After running driver optimisation:
```bash
# Check if PipeWire is running
systemctl --user status pipewire

# Start if not running
systemctl --user start pipewire

# Test audio routing
pw-play /usr/share/sounds/freedesktop/stereo/complete.oga
```

### Launch OBS with Optimised Settings

Use the provided launcher script:
```bash
obs-wayland    # Automatically sources optimised driver settings
```

Or manually source the environment:
```bash
source /etc/profile.d/obs-wayland.sh
obs
```

### Check Optimisation Report

After running `optimise_drivers.sh`, check the generated report:
```bash
cat $PWD/OBS_DRIVER_REPORT.txt
```

This shows GPU info, loaded drivers, environment variables, and recommended actions.

## Requirements

- `ffmpeg`, `v4l-utils`, `v4l2loopback-dkms`
- Optional: `uhubctl` (hub power control), `slop` (visual picker)
- For Nvidia: `nvidia-driver` 530+ recommended
- For GPU HW acceleration: `vainfo`, `libva-driver-*` (driver-specific)

```bash
sudo apt install ffmpeg v4l-utils v4l2loopback-dkms vainfo
```

For hardware video encoding on Nvidia:
```bash
sudo apt install nvidia-driver-latest-dkms
```

For AMD GPU:
```bash
sudo apt install mesa-vdpau-drivers libvdpau-va-gl libva-amd64-linux
```

For Intel GPU:
```bash
sudo apt install intel-media-driver libva-intel-driver
```
