#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <errno.h>
#include <inttypes.h>
#include <time.h>

static int set_interface_attribs(int fd, int speed) {
    struct termios tty;
    if (tcgetattr(fd, &tty) != 0) return -1;

    // cfmakeraw sets the terminal to a state where bytes are
    // passed exactly as received: no echo, no translations, no signals.
    cfmakeraw(&tty);

    // Set baud rate
    cfsetospeed(&tty, speed);
    cfsetispeed(&tty, speed);

    // 8-bit chars, enable receiver, ignore modem control lines
    tty.c_cflag &= ~CSIZE & ~HUPCL;
    tty.c_cflag |= CS8 | CREAD | CLOCAL;

    // Setup timing: non-blocking read with 0.5s timeout
    tty.c_cc[VMIN]  = 0;
    tty.c_cc[VTIME] = 10;

    if (tcsetattr(fd, TCSANOW, &tty) != 0) return -1;
    return 0;
}

int main(int argc, char **argv)
{
	unsigned char buf[256];
    int fd = open(argv[1], O_RDWR | O_NOCTTY);
    if (fd < 0) { perror("Open port"); return 1; }
    set_interface_attribs(fd, B1000000);
	tcflush(fd, TCIOFLUSH);
	
	// program SSID
	buf[0] = 0;
	strcpy(buf+1, argv[2]);
	if (write(fd, buf, 1+strlen(buf+1)+1) < 0) {
		printf("Could not write to serial..\n");
		exit(-1);
	}
	tcdrain(fd);
	
	// program PSK
	buf[0] = 1;
	strcpy(buf+1, argv[3]);
	if (write(fd, buf, 1+strlen(buf+1)+1) < 0) {
		printf("Could not write to serial..\n");
		exit(-1);
	}
	tcdrain(fd);

	// Store and reboot
	buf[0] = 2;
	if (write(fd, buf, 1) < 0) {
		printf("Could not write to serial..\n");
		exit(-1);
	}
	tcdrain(fd);
}
