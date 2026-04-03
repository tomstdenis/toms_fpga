#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <errno.h>

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
    tty.c_cc[VMIN]  = 100;
    tty.c_cc[VTIME] = 100;

    if (tcsetattr(fd, TCSANOW, &tty) != 0) return -1;
    return 0;
}

#define STRIDE 2048

int main(int argc, char **argv)
{
	uint8_t buf[2048];
	int rng;
	int x, y, fail;
	
    int fd = open(argv[1], O_RDWR | O_NOCTTY);
    if (fd < 0) { perror("Open port"); return 1; }
    set_interface_attribs(fd, B115200);
	tcflush(fd, TCIOFLUSH);
	
	rng = open("/dev/urandom", O_RDONLY);
	
	x = y = 0;
	for (;;) {
		// sync byte
		buf[0] = 0x5A;
		if (write(fd, &buf[0], 1) != 1) {
			printf("Could not write to serial port...\n");
			exit(-1);
		}
		tcdrain(fd);

		read(rng, buf, 2048);
		for (x = 0; x < STRIDE; x++) {
			printf("Writing byte: %04d\r", x);
			fflush(stdout);
			write(fd, &buf[x], 1);
			tcdrain(fd);
		}
		printf("\nDone writing...\n");
		for (x = 0; x < STRIDE; ) {
			uint8_t ch;
			fail = 0;
			printf("Reading byte: %04d\r", x);
			fflush(stdout);
			if (read(fd, &ch, 1) == 1) {
				if (ch != buf[x]) {
					printf("Byte at offset %d failed (%02x vs %02x)\n", x, ch, buf[x]);
					fail = 1;
				}
				++x;
			}
		}
		if (fail) {
			printf("Failed test %d\n", y);
			exit(-1);
		}
		++y;
		printf("\nPassed %d tests\n", y);
	}
	return 0;
}
	
