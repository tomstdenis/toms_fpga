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
    tty.c_cc[VMIN]  = 0;
    tty.c_cc[VTIME] = 10;

    if (tcsetattr(fd, TCSANOW, &tty) != 0) return -1;
    return 0;
}

int main(int argc, char **argv)
{
	FILE *f;
	int ch;
	int bytes = 0;
	
    int fd = open(argv[1], O_RDWR | O_NOCTTY);
    if (fd < 0) { perror("Open port"); return 1; }
    set_interface_attribs(fd, B115200);
    usleep(1000000);
	tcflush(fd, TCIOFLUSH);
	
	f = fopen(argv[2], "r");
	for (;;) {
		ch = fgetc(f);
		if (ch != EOF) {
			uint8_t b = ch;
			if (write(fd, &b, 1) != 1) {
				printf("\nError writing to UART\n");
				exit(-1);
			}
			tcdrain(fd);
			if (read(fd, &b, 1) == 1) {
				if (b == ch) {
					++bytes;
					printf("Wrote %4d (%d%% done)\r", bytes, (bytes * 100) / (4096 - 0x50));
					fflush(stdout);
				} else {
					printf("\nRead timed out\n");
					exit(-1);
				}
			} else {
				printf("\nReadback mismatch: %02x\n", b);
				exit(-1);
			}
		} else {
			break;
		}
	}
	fclose(f);
	close(fd);
	return 0;
}
	
