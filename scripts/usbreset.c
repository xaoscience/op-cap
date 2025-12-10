/* usbreset.c - small utility to usb reset a device node using ioctl */
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/usbdevice_fs.h>

int main(int argc, char **argv) {
    const char *filename;
    int fd;

    if (argc != 2) {
        fprintf(stderr, "Usage: usbreset <device-node (e.g. /dev/bus/usb/001/002)>\n");
        return 1;
    }
    filename = argv[1];
    fd = open(filename, O_WRONLY);
    if (fd < 0) {
        perror("Error opening device");
        return 1;
    }
    if (ioctl(fd, USBDEVFS_RESET, 0) < 0) {
        perror("Error in ioctl");
        close(fd);
        return 1;
    }
    printf("Reset successful on %s\n", filename);
    close(fd);
    return 0;
}
