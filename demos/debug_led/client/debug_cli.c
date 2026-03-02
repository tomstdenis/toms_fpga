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

void send_cmd(int fd, uint8_t *in, uint8_t *out)
{
	int x, n;
	if (write(fd, in, 18) != 18) {
		printf("Could not write packet to debugger\n");
		exit(-1);
	}
	tcdrain(fd);
	
	n = 18;
	while (n) {
		x = read(fd, out + 18 - n, n);
		n -= x;
	}
}

uint16_t enumerate_bus(int fd)
{
	uint8_t frame[18];
	uint16_t n;
	
	memset(frame, 0, sizeof frame);
	frame[16] = 0xFF; // address 0x7FFF is broadcast
	frame[17] = 0xFE;
	send_cmd(fd, frame, frame);
//	{ int x; for (x = 0; x < 18; x++) printf("%2x ", frame[x]); printf("\n"); }
	n = ((uint16_t)frame[14] << 8) | frame[15];
	return n;
}

void list_identities(int fd)
{
	uint8_t frame[18], allzero[16];
	uint16_t addr;
	int x;
	
	memset(allzero, 0, 16);
	printf("Identifying Devices...\n");
	for (addr = 0; addr < 32768; addr++) {
		memset(frame, 0, sizeof frame);
		frame[16] = (addr << 1) >> 8;
		frame[17] = (addr << 1) & 0xFF;
		send_cmd(fd, frame, frame);
		if (!memcmp(frame, allzero, 16)) {
			break;
		}
		printf("Node %04x: Identity = ", addr);
		for(x = 0; x < 16; x++) { printf("%02x ", frame[x]); }
		printf("\n");
	}
	printf("Done.\n");
}

void blink(int fd)
{
	uint8_t frame[18], loss[18];
	uint16_t addr = 0, x = 0;
	for (;;) {
		memset(frame, 0, sizeof frame);
		frame[16] = (addr << 1) >> 8;
		frame[17] = (addr << 1) & 0xFF;
		frame[17] |= 1;
		frame[15] = x;
		addr = (addr + 1) & 3;
		if (addr == 0) { x ^= 1 ; }
		send_cmd(fd, frame, loss);
		usleep(100000);
	}
}

int main(int argc, char **argv)
{	
    int fd = open(argv[1], O_RDWR | O_NOCTTY);
    if (fd < 0) { perror("Open port"); return 1; }
    set_interface_attribs(fd, B115200);
//    usleep(500000);
	tcflush(fd, TCIOFLUSH);
	
	printf("Bus has %u devices on it...\n", enumerate_bus(fd));
	list_identities(fd);
	blink(fd);

}
