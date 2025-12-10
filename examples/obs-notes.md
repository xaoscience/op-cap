# OBS Notes — Using the v4l2loopback feed instead of direct capture

1) Install v4l2loopback-dkms and v4l-utils. On Ubuntu:

```bash
sudo apt install v4l2loopback-dkms v4l-utils ffmpeg
```

2) The FFmpeg feed script `ffmpeg/feed.sh` writes to `/dev/video10`. In OBS, add a Video Capture Device and pick `/dev/video10` (labeled "USB_Capture_Loop") as the device. Set resolution and FPS to match the feed (auto-detected during install).

3) If the native device disconnects, the service `usb-capture-ffmpeg.service` will be restarted and OBS will typically reconnect to the v4l2loopback device automatically.

4) If OBS doesn't see the loopback device, reset it:
```bash
sudo modprobe -r v4l2loopback && sudo modprobe v4l2loopback video_nr=10 card_label="USB_Capture_Loop" exclusive_caps=1
```
Then restart OBS or re-add the video capture source.

4) If you still experience instability:
- Ensure the GPU is using `nvidia` driver but disable or configure `NVIDIA Persistence Mode` if needed.
- OBS may crash if hardware acceleration is used with certain drivers on X11; try switching to Wayland or disable HW acceleration (Settings -> Advanced -> Renderer).
- Avoid capturing the physical device directly in OBS. Use the v4l2loopback, because feeding the same device to OBS can cause OBS to crash on driver bugs.

5) Hiding logos / overlay:
- If the device has no control to remove overlay, `ffmpeg/feed.sh` uses `delogo` or `crop` filter; tune x,y,w,h to your desired area.
- Example `delogo` settings: `delogo=x=3500:y=20:w=300:h=100:show=0` to hide a top-right logo.

6) Multiple cameras
- If you use multiple physical capture devices, run multiple FFmpeg feeds to separate v4l2loopback devices (e.g., /dev/video3, /dev/video4). Use `v4l2loopback` kernel module parameters to pre-configure them.

7) Rebinding drivers on reconnect
- The `auto_reconnect.sh` script will attempt to unbind and bind the driver for the device on disconnect and call USB reset via pysysfs - see `usb_reset.sh` for details.

8) Logging
- If you need logs, `journalctl -u usb-capture-monitor.service -f` and `journalctl -u usb-capture-ffmpeg.service -f` show runtime logs.


Good luck!
