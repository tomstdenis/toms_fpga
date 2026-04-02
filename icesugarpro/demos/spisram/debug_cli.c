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
		for(x = 0; x < PAYLOAD-3-(SRAM_ADDR_WIDTH/8); x++) { printf("%02x", frame[x]); }
		printf("], addr=%02x%02x%02x job_counter=%02x%02x, done=%d, tag=%d, state=%d\n", frame[PAYLOAD-6], frame[PAYLOAD-5], frame[PAYLOAD-4], frame[PAYLOAD-3], frame[PAYLOAD-2], frame[PAYLOAD-1]>>6, (frame[PAYLOAD-1]>>3)&7, frame[PAYLOAD-1]&7);
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
		read(rng, frame, PAYLOAD-3);
		frame[PAYLOAD] = (addr << 1) >> 8;			// assign the node address, we're reading (so LSB is 0), and we're reading identity so PAYLOAD-1 must be zero
		frame[PAYLOAD+1] = 1 | ((addr << 1) & 0xFF);// write command plus bottom seven bits of address
		send_cmd(fd, frame, frame);
		if (!memcmp(frame, allzero, PAYLOAD)) {
			break;
		}
		printf("Node %04x: Payload = [", addr);
		for(x = 0; x < PAYLOAD-3-(SRAM_ADDR_WIDTH/8); x++) { printf("%02x", frame[x]); }
		printf("], addr=%02x%02x%02x\n", frame[PAYLOAD-6], frame[PAYLOAD-5], frame[PAYLOAD-4]);
	}
	close(rng);
	printf("Done.\n");
}

void test_node(int fd, uint16_t node)
{
	uint8_t frame[FRAME], loss[FRAME];
	uint64_t tests = 0;
	int rng, y;
	
	rng = open("/dev/urandom", O_RDONLY);
	for (;;) {
		// configure a node with random data
		memset(frame, 0, sizeof frame);
		switch((tests / BITS) % 10) {
			case 0: // all zeroes
				break;
			case 1: // all ones
				memset(frame, 0xFF, BITS/8);
				break;
			case 2: // marching one
				frame[(tests/8) % (BITS/8)] = 1 << (tests % 8);
				break;
			case 3: // alternating F's to test the SIO lines violently swinging from 1 to 0 
				memset(frame, 0xF0, BITS/8);
				break;
			case 4: // alternating lines to try and catch crosstalk
				memset(frame, 0xA5, BITS/8);
				break;
			case 5: // slam, all high for a run then all low meant to catch edge faults
				for (y = 0; y < (BITS/8); y++) {
					if (!((y & 3) >= 2)) {
						frame[y] = 0xFF;
					} else {
						frame[y] = 0;
					}
				}
				break;
			default: // random data
				read(rng, frame, BITS/8);
				break;
		}
		read(rng, frame+(BITS/8), 3); // randomize the address;

/*
		frame[BITS/8] &= 0x00; // force MSB to zero
		frame[1 + BITS/8] &= 0x00; // force MSB to zero
		
		frame[0+BITS/8] = 0x0A;
		frame[1+BITS/8] = 0xAA;
		frame[2+BITS/8] = 0xAA;
*/		
		frame[PAYLOAD] = (node << 1) >> 8;			// assign the node address, we're reading (so LSB is 0), and we're reading identity so PAYLOAD-1 must be zero
		frame[PAYLOAD+1] = 1 | ((node << 1) & 0xFF);// write command plus bottom seven bits of address
		send_cmd(fd, frame, loss);
		if (memcmp(frame, loss, FRAME)) {
			printf("Returned frame on write differs when it shouldn't\n");
			{ int x; for (x = 0; x < FRAME; x++) printf("%2x ", frame[x]); printf("\n"); }
			{ int x; for (x = 0; x < FRAME; x++) printf("%2x ", loss[x]); printf("\n"); }
			exit(-1);
		}
		// now read back the node
		for (;;) {
			memset(frame, 0, sizeof frame);
			frame[PAYLOAD] = (node << 1) >> 8;			// assign the node address, we're reading (so LSB is 0), and we're reading identity so PAYLOAD-1 must be zero
			frame[PAYLOAD+1] = (node << 1) & 0xFF;
			frame[PAYLOAD-1] = 1;						// assign a non-zero READ CMD
			send_cmd(fd, frame, frame);
			if (frame[PAYLOAD-1]>>6) {
				// done bit is set compare payload
				if (memcmp(loss, frame, PAYLOAD-3-(SRAM_ADDR_WIDTH/8))) {
					// read back SRAM failed
					printf("Returned SRAM data is wrong (Test #%ld)\n", tests);
					printf("Delta:    "); { int x; for (x = 0; x < FRAME; x++) printf("%02x ", loss[x] ^ frame[x]); printf("\n"); }
					printf("Output:   "); { int x; for (x = 0; x < FRAME; x++) printf("%02x ", frame[x]); printf("\n"); }
					printf("Original: "); { int x; for (x = 0; x < FRAME; x++) printf("%02x ", loss[x]); printf("\n"); }
					exit(-1);
				}
				break;
			}
		}
//		usleep(1000000);
		++tests;
		if (!(tests % BITS	)) {
			int x;
			printf("Tests passed: %10ld, ", tests);
			fflush(stdout);
			printf("Payload = [");
			for(x = 0; x < PAYLOAD-3-(SRAM_ADDR_WIDTH/8); x++) { printf("%02x", frame[x]); }
			printf("], addr=%02x%02x%02x\n", frame[PAYLOAD-6], frame[PAYLOAD-5], frame[PAYLOAD-4]);
		}
	}	
}


int main(int argc, char **argv)
{	
    int nodes, fd = open(argv[1], O_RDWR | O_NOCTTY);
    if (fd < 0) { perror("Open port"); return 1; }
    set_interface_attribs(fd, B1000000);
	tcflush(fd, TCIOFLUSH);
	
	printf("Bus has %u devices on it...\n", nodes = enumerate_bus(fd));
	list_identities(fd);
	dump_nodes(fd, nodes);
	test_node(fd, 0x0000);	
}
