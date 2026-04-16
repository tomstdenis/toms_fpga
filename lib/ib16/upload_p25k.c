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

int main(int argc, char **argv)
{
	FILE *f;
	int ch;
	int bytes = 0;
	int size;
	uint8_t buf;
	
    int fd = open(argv[1], O_RDWR | O_NOCTTY);
    if (fd < 0) { perror("Open port"); return 1; }
    set_interface_attribs(fd, B230400);
	tcflush(fd, TCIOFLUSH);
	usleep(50000);
	
	// send magic byte
	buf = 0x5A;
	if (write(fd, &buf, 1) != 1) {
		printf("Error writing to UART\n");
		exit(-1);
	}
	tcdrain(fd);

	f = fopen(argv[2], "r");
	fseek(f, 0, SEEK_END);
	size = ftell(f);
	fseek(f, 0, SEEK_SET);

	// send # of pages to program
	buf = size/256;
	if (write(fd, &buf, 1) != 1) {
		printf("Error writing to UART\n");
		exit(-1);
	}
	tcdrain(fd);

	bytes = 0;
	while (bytes < size) {
		if (!(bytes & 255)) {
			printf(".");
			fflush(stdout);
		}
		ch = fgetc(f);
		if (ch != EOF) {
			uint8_t bb, tb, b = ch;
			bb = (b >> 4) + 0x5A;
			if (write(fd, &bb, 1) != 1) {
				printf("\nError writing to UART\n");
				exit(-1);
			}
			tcdrain(fd);
			if (bytes < 256) {
				if (read(fd, &tb, 1) == 1) {
					if (tb == bb) {
					} else {
						printf("\nReadback mismatch: %02x\n", b);
						exit(-1);
					}
				} else {
						printf("\nRead timed out\n");
					exit(-1);
				}
			}

			bb = (b & 0xF) + 0x5A;
			if (write(fd, &bb, 1) != 1) {
				printf("\nError writing to UART\n");
				exit(-1);
			}
			tcdrain(fd);
			if (bytes++ < 256) {
				if (read(fd, &tb, 1) == 1) {
					if (tb == bb) {
					} else {
						printf("\nReadback mismatch: %02x\n", b);
						exit(-1);
					}
				} else {
						printf("\nRead timed out\n");
					exit(-1);
				}
			}


		} else {
			break;
		}
	}
	printf("\nDone\n");
	fclose(f);
	close(fd);
	return 0;
}
	
