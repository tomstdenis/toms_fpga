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

#define PAYLOAD ((BITS+24)/8)												// how many bytes of payload must match BITS/8 in your instantiated debuggers
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

// send a frame in, read one back
void send_cmd(int fd, uint8_t *in, uint8_t *out)
{
	int x, n;
	uint8_t tmp[1+FRAME];
	tmp[0] = 0xAA; // header byte
	memcpy(tmp+1, in, FRAME);
	if (write(fd, tmp, FRAME+1) != FRAME+1) {
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

// tells the debug nodes to enumerate themselves, returns the # of nodes for informational purposes
uint16_t enumerate_bus(int fd)
{
	uint8_t frame[FRAME];
	uint16_t n;
	
	memset(frame, 0, sizeof frame);
	frame[PAYLOAD] = 0xFF; // address 0x7FFF is broadcast
	frame[PAYLOAD+1] = 0xFE;
//	{ int x; for (x = 0; x < 18; x++) printf("%2x ", frame[x]); printf("\n"); }
	send_cmd(fd, frame, frame);
//	{ int x; for (x = 0; x < 18; x++) printf("%2x ", frame[x]); printf("\n"); }
	n = ((uint16_t)frame[PAYLOAD-2] << 8) | frame[PAYLOAD-1];
	return n;
}

// print out all of the identities
void list_identities(int fd)
{
	uint8_t frame[FRAME], allzero[PAYLOAD];
	uint16_t addr;
	int x;
	
	memset(allzero, 0, PAYLOAD);
	printf("Identifying Devices...\n");
	for (addr = 0; addr < 32768; addr++) {
		memset(frame, 0, sizeof frame);
		frame[PAYLOAD] = (addr << 1) >> 8;			// assign the node address, we're reading (so LSB is 0), and we're reading identity so PAYLOAD-1 must be zero
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

// print out all of the nodes
void dump_nodes(int fd, int nodes)
{
	uint8_t frame[FRAME], allzero[PAYLOAD];
	uint16_t addr;
	int x;
	
	memset(allzero, 0, PAYLOAD);
	printf("Dumping nodes...\n");
	for (addr = 0; addr < nodes; addr++) {
		memset(frame, 0, sizeof frame);
		frame[PAYLOAD] = (addr << 1) >> 8;			// assign the node address, we're reading (so LSB is 0), and we're reading identity so PAYLOAD-1 must be zero
		frame[PAYLOAD+1] = (addr << 1) & 0xFF;
		frame[PAYLOAD-1] = 1;						// assign a non-zero READ CMD
		send_cmd(fd, frame, frame);
		if (!memcmp(frame, allzero, PAYLOAD)) {
			break;
		}
		printf("Node %04x: Payload = [", addr);
		for(x = 0; x < PAYLOAD-3; x++) { printf("%02x", frame[x]); }
		printf("], job_counter=%x%x, done=%d, tag=%d, state=%d\n", frame[PAYLOAD-3], frame[PAYLOAD-2], frame[PAYLOAD-1]>>6, (frame[PAYLOAD-1]>>3)&7, frame[PAYLOAD-1]&7);
	}
	printf("Done.\n");
}

// print out all of the nodes
void rand_nodes(int fd, int nodes)
{
	uint8_t frame[FRAME], allzero[PAYLOAD];
	uint16_t addr;
	int x, rng;
	
	memset(allzero, 0, PAYLOAD);
	printf("Randing nodes...\n");
	rng = open("/dev/urandom", O_RDONLY);
	for (addr = 0; addr < nodes; addr++) {
		memset(frame, 0, sizeof frame);
		read(rng, frame, PAYLOAD-1);
		frame[PAYLOAD] = (addr << 1) >> 8;			// assign the node address, we're reading (so LSB is 0), and we're reading identity so PAYLOAD-1 must be zero
		frame[PAYLOAD+1] = 1 | ((addr << 1) & 0xFF);// write command plus bottom seven bits of address
		send_cmd(fd, frame, frame);
		if (!memcmp(frame, allzero, PAYLOAD)) {
			break;
		}
		printf("Node %04x: Payload = [", addr);
		for(x = 0; x < PAYLOAD-3; x++) { printf("%02x", frame[x]); }
		printf("]\n");
	}
	close(rng);
	printf("Done.\n");
}

int main(int argc, char **argv)
{	
    int nodes, fd = open(argv[1], O_RDWR | O_NOCTTY);
    if (fd < 0) { perror("Open port"); return 1; }
    set_interface_attribs(fd, B115200);
	tcflush(fd, TCIOFLUSH);
	
	printf("Bus has %u devices on it...\n", nodes = enumerate_bus(fd));
	list_identities(fd);
	dump_nodes(fd, nodes);
	rand_nodes(fd, nodes);
	dump_nodes(fd, nodes);
	
}
