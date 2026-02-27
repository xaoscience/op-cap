/*
 * v4l2-hdr-shim.c — LD_PRELOAD shim for HDR colorspace on v4l2loopback
 *
 * Problem: FFmpeg's v4l2 output muxer always writes colorspace=V4L2_COLORSPACE_DEFAULT
 * (sRGB) when it calls VIDIOC_S_FMT on a loopback device. This is a hard-coded
 * default in the muxer — it has no API for passing HDR colorspace through.
 * Readers (OBS) then call VIDIOC_G_FMT and see sRGB, so the stream is never
 * classified as HDR regardless of what metadata is in the HEVC/NV12 bitstream.
 *
 * Fix: intercept ioctl(VIDIOC_S_FMT) calls from FFmpeg (the loopback writer).
 * When the target pixel format is NV12 and the output type is VIDEO_OUTPUT,
 * patch the colorspace fields to BT.2020/PQ before the syscall reaches the
 * kernel. v4l2loopback then propagates these values to VIDIOC_G_FMT on the
 * read side, so OBS sees the correct HDR colorspace from the moment it opens
 * the device.
 *
 * Build:
 *   gcc -shared -fPIC -O2 -o v4l2-hdr-shim.so v4l2-hdr-shim.c -ldl
 *
 * Usage (in feed.sh):
 *   LD_PRELOAD=/path/to/v4l2-hdr-shim.so ffmpeg ...
 *
 * Environment overrides:
 *   V4L2_HDR_SHIM_DEVICE  — loopback device path to target (default: empty → any OUTPUT device)
 *   V4L2_HDR_SHIM_DISABLE — set to 1 to bypass shim entirely
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdarg.h>
#include <sys/ioctl.h>
#include <linux/videodev2.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

/* Resolved at first call */
static int (*real_ioctl)(int, unsigned long, ...) = NULL;

/* Resolved once; empty string means "any OUTPUT device" */
static const char *target_dev = NULL;
static int         shim_disabled = 0;
static int         shim_init_done = 0;

static void shim_init(void) {
    if (shim_init_done) return;
    shim_init_done = 1;

    real_ioctl = dlsym(RTLD_NEXT, "ioctl");
    if (!real_ioctl) {
        fprintf(stderr, "[v4l2-hdr-shim] FATAL: cannot resolve ioctl via RTLD_NEXT\n");
        abort();
    }

    const char *env_dis = getenv("V4L2_HDR_SHIM_DISABLE");
    if (env_dis && env_dis[0] == '1') {
        shim_disabled = 1;
        return;
    }

    const char *env_dev = getenv("V4L2_HDR_SHIM_DEVICE");
    target_dev = (env_dev && env_dev[0]) ? env_dev : "";
}

/*
 * Resolve /proc/self/fd/<fd> to a device path and compare with target.
 * Returns 1 if we should patch this fd, 0 otherwise.
 */
static int should_patch_fd(int fd) {
    if (!target_dev || target_dev[0] == '\0') {
        /* No specific device — patch any V4L2 OUTPUT device */
        return 1;
    }
    char link[256] = {0};
    char proc_path[64];
    snprintf(proc_path, sizeof(proc_path), "/proc/self/fd/%d", fd);
    ssize_t n = readlink(proc_path, link, sizeof(link) - 1);
    if (n <= 0) return 0;
    link[n] = '\0';
    return (strcmp(link, target_dev) == 0);
}

int ioctl(int fd, unsigned long request, ...) {
    va_list args;
    va_start(args, request);
    void *arg = va_arg(args, void *);
    va_end(args);

    shim_init();

    if (!shim_disabled && request == VIDIOC_S_FMT && arg) {
        struct v4l2_format *fmt = (struct v4l2_format *)arg;

        /*
         * Only patch the OUTPUT side (writer = FFmpeg feeding the loopback).
         * V4L2_BUF_TYPE_VIDEO_OUTPUT = 2
         * The NV12 fourcc: V4L2_PIX_FMT_NV12 = 0x3231564e ('NV12')
         * p010le fourcc:   V4L2_PIX_FMT_P010  = 0x30313050 ('P010')
         * We patch regardless of pixelformat — the shim is only loaded for feed.sh.
         */
        if (fmt->type == V4L2_BUF_TYPE_VIDEO_OUTPUT && should_patch_fd(fd)) {
            /* BT.2020 HDR10 colorspace fields */
            fmt->fmt.pix.colorspace  = V4L2_COLORSPACE_BT2020;     /* 9  */
            fmt->fmt.pix.xfer_func  = V4L2_XFER_FUNC_SMPTE2084;   /* 6  — PQ */
            fmt->fmt.pix.ycbcr_enc  = V4L2_YCBCR_ENC_BT2020;      /* 10 */
            fmt->fmt.pix.quantization = V4L2_QUANTIZATION_LIM_RANGE; /* 2 */

#ifdef V4L2_HDR_SHIM_DEBUG
            fprintf(stderr,
                "[v4l2-hdr-shim] patched VIDIOC_S_FMT fd=%d "
                "colorspace=9(BT2020) xfer=6(PQ) ycbcr=10 quant=2\n", fd);
#endif
        }
    }

    return real_ioctl(fd, request, arg);
}
