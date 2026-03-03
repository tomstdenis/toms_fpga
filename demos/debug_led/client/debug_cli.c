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

#define PAYLOAD 16												// how many bytes of payload must match BITS/8 in your instantiated debuggers
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

void send_cmd(int fd, uint8_t *in, uint8_t *out)
{
	int x, n;
	if (write(fd, in, FRAME) != FRAME) {
		printf("Could not write packet to debugger\n");
		exit(-1);
	}
	tcdrain(fd);
	
	n = FRAME;
	while (n) {
		x = read(fd, out + FRAME - n, n);
		n -= x;
	}
}

uint16_t enumerate_bus(int fd)
{
	uint8_t frame[FRAME];
	uint16_t n;
	
	memset(frame, 0, sizeof frame);
	frame[PAYLOAD] = 0xFF; // address 0x7FFF is broadcast
	frame[PAYLOAD+1] = 0xFE;
	send_cmd(fd, frame, frame);
//	{ int x; for (x = 0; x < 18; x++) printf("%2x ", frame[x]); printf("\n"); }
	n = ((uint16_t)frame[PAYLOAD-2] << 8) | frame[PAYLOAD-1];
	return n;
}

void list_identities(int fd)
{
	uint8_t frame[FRAME], allzero[PAYLOAD];
	uint16_t addr;
	int x;
	
	memset(allzero, 0, PAYLOAD);
	printf("Identifying Devices...\n");
	for (addr = 0; addr < 32768; addr++) {
		memset(frame, 0, sizeof frame);
		frame[PAYLOAD] = (addr << 1) >> 8;
		frame[PAYLOAD+1] = (addr << 1) & 0xFF;
		send_cmd(fd, frame, frame);
		if (!memcmp(frame, allzero, PAYLOAD)) {
			break;
		}
		printf("Node %04x: Identity = ", addr);
		for(x = 0; x < PAYLOAD; x++) { printf("%02x ", frame[x]); }
		printf("\n");
	}
	printf("Done.\n");
}

void blink(int fd)
{
	uint8_t frame[FRAME], loss[FRAME];
	uint16_t addr = 0, x = 0;
	unsigned loops;
	int rng;
	rng = open("/dev/urandom", O_RDONLY);
	for (loops = 0; loops < -1; loops++) {
		memset(frame, 0, sizeof frame);
		frame[PAYLOAD] = (addr << 1) >> 8;
		frame[PAYLOAD+1] = (addr << 1) & 0xFF;
		frame[PAYLOAD+1] |= 1;
		frame[PAYLOAD-1] = x;
		if (read(rng, frame, PAYLOAD-1) != PAYLOAD-1) {
			printf("Could not read %d bytes from /dev/urandom...\n", PAYLOAD-1);
			exit(-1);
		}
		addr = (addr + 1) & 3;
		if (addr == 0) { x ^= 1 ; }
		send_cmd(fd, frame, loss);
		if (memcmp(frame, loss, FRAME)) {									// writes should pass through the write command
			printf("Return write command differs unexpectedly...\n");
			exit(-1);
		}
		loss[PAYLOAD+1] &= ~1; // READ
		loss[PAYLOAD-1] = 1; // don't send READ IDENTITY command
		send_cmd(fd, loss, loss);
		if (memcmp(frame, loss, PAYLOAD)) {									// we should get the payload back
			printf("Returned payload differs unexpectedly...\n");
			{ int x; for (x = 0; x < FRAME; x++) printf("%2x ", loss[x]); printf("\n"); }
			{ int x; for (x = 0; x < FRAME; x++) printf("%2x ", frame[x]); printf("\n"); }
			exit(-1);
		}
		usleep(50000);
	}
	close(rng);
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
