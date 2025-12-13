# OBS Wayland GPU Driver Optimisation Guide

## Overview

OBS Studio frequently crashes on Wayland due to graphics driver incompatibilities, particularly with:
- **Explicit Sync Issues** (Nvidia GPU primary issue)
- **PipeWire Screen Capture** hangs or crashes
- **Projector Windows** causing immediate crashes
- **Hardware Acceleration** conflicts

The `optimise_drivers.sh` script automatically configures your GPU driver for stable OBS operation on Wayland.

## Problem Statement

### Nvidia (Most Common)
Wayland uses explicit sync protocol for GPU synchronisation. Nvidia's driver implementation has bugs that cause:
- OBS crash when opening projectors
- Screen capture (PipeWire) hanging or crashing
- Streaming disconnections

**Solution:** Disable explicit sync with `__NV_DISABLE_EXPLICIT_SYNC=1`

### AMD & Intel
While generally more stable, these drivers benefit from:
- Wayland-specific optimisations
- PipeWire latency tuning
- VA-API hardware acceleration setup

## Quick Start

### Automatic Detection & Optimisation

```bash
cd /home/jnxlr/PRO/WEB/CST/op-cap

# Build and optimise in one step
make install-with-drivers

# Or optimise GPU drivers only
make optimise-drivers

# Manual driver selection (if auto-detection fails)
sudo ./scripts/optimise_drivers.sh --nvidia    # For Nvidia
sudo ./scripts/optimise_drivers.sh --amd       # For AMD
sudo ./scripts/optimise_drivers.sh --intel     # For Intel
```

### Launch OBS with Optimisations Applied

```bash
# Use the provided launcher (automatically sources optimisations)
obs-wayland

# Or manually source then launch
source /etc/profile.d/obs-wayland.sh
obs
```

## What the Script Does

### 1. Detects GPU Hardware
```bash
lspci | grep -i nvidia/amd/intel
lsmod | grep nvidia/amdgpu/i915
```

### 2. Creates Environment Configuration
Creates `/etc/profile.d/obs-wayland.sh` with GPU-specific optimisations:

#### Nvidia Configuration
```bash
export __NV_DISABLE_EXPLICIT_SYNC=1          # Critical: Disable buggy explicit sync
export QT_QPA_PLATFORM=wayland               # Use Wayland for Qt apps
export GDK_BACKEND=wayland                   # Use Wayland for GTK apps
export LIBVA_DRIVER_NAME=nvidia              # VA-API driver
export PIPEWIRE_LATENCY=64/48000             # Optimise PipeWire audio
```

#### AMD Configuration
```bash
export RADEON_ENABLE_ACE=1                   # Enable color block compression
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland
export LIBVA_DRIVER_NAME=radeonsi            # VA-API hardware acceleration
export PIPEWIRE_LATENCY=64/48000
```

#### Intel Configuration
```bash
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland
export LIBVA_DRIVER_NAME=iHD                 # Intel Media Driver
export PIPEWIRE_LATENCY=64/48000
```

### 3. Creates OBS Launcher Script
`/usr/local/bin/obs-wayland` — Convenient launcher that automatically sources optimisations.

### 4. Generates System Report
`OBS_DRIVER_REPORT.txt` — Diagnostic information including:
- GPU hardware detected
- Driver modules loaded
- Current display server (Wayland/X11)
- Recommended additional actions

## System Requirements

### Nvidia (Recommended: Driver 530+)
```bash
# Check current version
nvidia-smi

# Update if needed
sudo apt install nvidia-driver-latest-dkms

# Recommended kernel parameter (add to GRUB)
nvidia-drm.modeset=1
```

### AMD
```bash
# Hardware acceleration
sudo apt install mesa-vdpau-drivers libvdpau-va-gl libva-amd64-linux
```

### Intel
```bash
# Hardware acceleration
sudo apt install intel-media-driver libva-intel-driver
```

### All GPUs
```bash
# Common dependencies
sudo apt install ffmpeg v4l-utils v4l2loopback-dkms vainfo pipewire pipewire-audio-client-libraries
```

## Troubleshooting

### OBS Still Crashes on Wayland

#### Verify Environment Variables Are Set
```bash
source /etc/profile.d/obs-wayland.sh
env | grep -E 'NV_DISABLE|QT_QPA|LIBVA'
```

Expected output for Nvidia:
```
__NV_DISABLE_EXPLICIT_SYNC=1
QT_QPA_PLATFORM=wayland
GDK_BACKEND=wayland
LIBVA_DRIVER_NAME=nvidia
```

#### Check OBS is Running on Wayland
```bash
# While OBS is running, from another terminal:
ps aux | grep obs
env | grep WAYLAND

# OBS should show Wayland socket connection
```

#### Verify PipeWire is Running
```bash
systemctl --user status pipewire
# If not running:
systemctl --user start pipewire
```

#### Check GPU Driver Version
```bash
nvidia-smi --query-gpu=driver_version --format=csv,noheader

# Nvidia: Should be 530+
# AMD: Latest available
# Intel: Latest available
```

#### Review System Report
```bash
cat OBS_DRIVER_REPORT.txt
```

### Screen Capture (PipeWire) Still Hangs

**Issue:** PipeWire screen capture may hang even with optimisations.

**Workarounds:**
1. Use **X11 Screen Capture** instead (if available)
2. Use **Window Capture** instead of screen capture
3. Reduce screen resolution in OBS settings
4. Update OBS to latest version (`sudo apt install obs-studio`)

**Manual PipeWire test:**
```bash
# Verify PipeWire is accessible
pw-list-objects core

# Check for audio/video permissions
pw-dump | grep node | head -10
```

### Projector Window Still Crashes

**Issue:** Opening OBS projector causes immediate crash on Wayland.

**Verification:** This is typically fixed by `__NV_DISABLE_EXPLICIT_SYNC=1` on Nvidia.

**If still occurs:**
1. Use fullscreen projector mode instead of window mode
2. Check OBS version: `obs --version`
3. Try X11 session (if available): `echo $XDG_SESSION_TYPE`

### VA-API Hardware Acceleration Not Working

```bash
# Check VA-API support
vainfo

# Should show GPU-specific acceleration (e.g., "Libva initialised" with driver info)

# If not available:
# - Nvidia: Install nvidia-driver with NVENC support
# - AMD: Install mesa-vdpau-drivers
# - Intel: Install intel-media-driver
```

## Advanced Configuration

### Manual Environment Adjustment

Edit `/etc/profile.d/obs-wayland.sh` to modify settings:

```bash
sudo nano /etc/profile.d/obs-wayland.sh
```

Common adjustments:

```bash
# Disable Wayland backend (fallback to X11)
unset QT_QPA_PLATFORM
unset GDK_BACKEND

# Reduce PipeWire latency (may improve responsiveness)
export PIPEWIRE_LATENCY=32/48000

# Enable debug output (verbose logging)
export __NV_DEBUG=6
export MESA_DEBUG=1
```

### Nvidia-Specific Tweaks

```bash
# Enable GPU reset timeout recovery
export __NV_DRIVER_CAPABILITIES=graphics,compat32,display,utility

# Use specific GPU (if system has multiple)
export CUDA_VISIBLE_DEVICES=0

# Disable GPU power management (better stability, more power usage)
export __NV_PM=0
```

## Performance Tuning

### OBS Video Settings (Wayland-optimised)

1. **Settings > Video:**
   - Renderer: GPU-based (OpenGL/Vulkan)
   - Color Space: Native (recommended)
   - Color Range: Full (when available)

2. **Settings > Advanced:**
   - Hardware Acceleration: Enable (checked)
   - NVENC Encoder: Use if encoding video

3. **Video Capture Device Settings:**
   - Use `/dev/video10` (v4l2loopback isolation)
   - Resolution: 3840x2160 @ 30fps (default)
   - Format: NV12 (if supported)

### Audio Settings (PipeWire)

1. **Settings > Audio:**
   - Samples/Second: 48000 Hz (standard)
   - Channels: Stereo
   - Desktops Audio Device: PipeWire (default)

## Verification Checklist

After running optimisation:

- [ ] Script ran successfully without errors
- [ ] `OBS_DRIVER_REPORT.txt` generated in project directory
- [ ] `/etc/profile.d/obs-wayland.sh` exists and is readable
- [ ] `/usr/local/bin/obs-wayland` launcher exists and is executable
- [ ] Running `obs-wayland` launches OBS without crashes
- [ ] `XDG_SESSION_TYPE` is `wayland` (not `x11`)
- [ ] Screen capture works without hanging (test for 10+ seconds)
- [ ] Can open and interact with projector window
- [ ] PipeWire audio works: `pw-play /usr/share/sounds/freedesktop/stereo/complete.oga`
- [ ] GPU hardware acceleration enabled in OBS settings

## Revert Changes

If optimisations cause issues:

```bash
# Remove Wayland optimisation script
sudo rm /etc/profile.d/obs-wayland.sh

# Remove launcher
sudo rm /usr/local/bin/obs-wayland

# Re-add any unset environment variables in ~/.bashrc
echo "" >> ~/.bashrc
```

Then restart shell or reboot.

## Additional Resources

- [OBS Wayland Support](https://github.com/obsproject/obs-studio/wiki/Wayland-Support)
- [Nvidia Wayland Issues](https://forums.developer.nvidia.com/t/wayland-support/)
- [PipeWire Documentation](https://docs.pipewire.org/)
- [VA-API Hardware Acceleration](https://en.wikipedia.org/wiki/Video_Acceleration_API)

## Support

For issues specific to this op-cap project:
```bash
# Check service logs
journalctl -u usb-capture-ffmpeg.service -f

# Generate system diagnostics
cat OBS_DRIVER_REPORT.txt
```

For OBS-specific issues on Wayland:
- Check OBS logs: `~/.config/obs-studio/logs/`
- Review error messages: `obs --loglevel verbose`
