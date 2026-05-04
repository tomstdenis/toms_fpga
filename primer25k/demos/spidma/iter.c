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

#define BITS 32
#define SRAM_ADDR_WIDTH 24

#define PAYLOAD ((BITS+SRAM_ADDR_WIDTH+24)/8)												// how many bytes of payload must match BITS/8 in your instantiated debuggers
#define FRAME   (PAYLOAD+2)
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
    int nodes, fd = open(argv[1], O_RDWR | O_NOCTTY);
    if (fd < 0) { perror("Open port"); return 1; }
    set_interface_attribs(fd, B115200);
	tcflush(fd, TCIOFLUSH);
	
	int tests = 0;
	
	for (;;) {
		char b;
		write(fd, &b, 1);
		tcdrain(fd);
		while (read(fd, &b, 1) != 1);
		if (b == '2') {
			printf("\nFailed!\n");
			exit(-1);
		}
		++tests;
		printf("Passed %9d tests\r", tests); fflush(stdout);
		usleep(1);
	}
}
