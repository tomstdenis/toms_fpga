#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <errno.h>
#include <inttypes.h>

#define OP_READ  0x80
#define OP_WRITE 0x40
#define OP_HALT  0x20

#define OP_LEN(x) ((x - 1) & 3)

// 8MB buffer 
//#define MEM_SIZE (1UL<<23)

// standard test (64KB)
//#define MEM_SIZE (1UL<<16)

// smaller to test (8KB)
#define MEM_SIZE (1UL<<13)

// smallest to test (2KB)
//#define MEM_SIZE (1UL<<11)

uint8_t memory[MEM_SIZE], init[MEM_SIZE];
uint64_t lines = 0;

int fd;
static int set_interface_attribs(int speed) {
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


void write_opcode(uint32_t opcode, uint32_t addr, uint32_t value, uint32_t len)
{
	uint8_t b, buf[8], rbuf[8], x;
	
	// first write command to file
	x = 0;
	b = opcode | OP_LEN(len);   buf[x++] = b;
	b = addr >> 16;             buf[x++] = b;
	b = (addr >> 8) & 0xFF;     buf[x++] = b;
	b = addr & 0xFF;            buf[x++] = b;
	b = (value >> 24) & 0xFF;   buf[x++] = b;
	b = (value >> 16) & 0xFF;   buf[x++] = b;
	b = (value >> 8) & 0xFF;    buf[x++] = b;
	b = value & 0xFF;           buf[x++] = b;
	
	// write buffer
	if (write(fd, buf, 8) != 8) {
		printf("Serial write failed, so sad\n");
		exit(-1);
	}
	tcdrain(fd);

	// read 1 char back (should be 0xAA for pass, 0x55 for fail)
	if (read(fd, &b, 1) != 1) {
		printf("\nCould not read from serial...\n");
		exit(-1);
	}
	
	if (b != 0xAA) {
		printf("\nRead back 0x%x instead of 0xAA...\n", b);
		exit(-1);
	}
	
	lines++;
}

// write out value[31:(32 - len)]
void gen_write(uint32_t addr, uint32_t value, uint32_t len)
{
	write_opcode(OP_WRITE, addr, value, len);
	
	// now do the op
	while (len--) {
		init[addr & (MEM_SIZE - 1)]     = 1;
		memory[addr++ & (MEM_SIZE - 1)] = (value >> 24) & 0xFF;
		value <<= 8;
	}	
}

// read in len bytes
void gen_read(uint32_t addr, uint32_t len)
{
	uint32_t value = 0, olen = len, oaddr = addr;
	
	// read into memory
	while (len--) {
		if (!init[addr & (MEM_SIZE - 1)]) {
			printf("Address %lu was not initialized before reading!\n", addr & (MEM_SIZE - 1));
			exit(-1);
		}
		value = (value << 8) | memory[addr++ & (MEM_SIZE - 1)];
	}
	// shift up to MSB
	if (olen != 4) {
		value <<= 8 * (4 - olen);
	}
	write_opcode(OP_READ, oaddr, value, olen);
}

FILE *rng;
uint32_t read_rng(uint32_t len)
{
	uint32_t value = 0, olen = len;
	uint8_t b;
	
	while (len--) {
		fread(&b, 1, 1, rng);
		value = (value << 8) | b;
	}
	if (olen != 4) {
		value <<= 8 * (4 - olen);
	}
	return value;
}

int main(int argc, char **argv)
{
	uint32_t x;
	uint32_t r, bl;
	
    fd = open(argv[1], O_RDWR | O_NOCTTY);
    if (fd < 0) { perror("Open port"); return 1; }
    set_interface_attribs(B1000000);
	tcflush(fd, TCIOFLUSH);

	rng = fopen("/dev/urandom", "r");
	memset(memory, 0, sizeof memory);
	memset(init, 0, sizeof init);

	// initialize memory
	printf("Initializing memory:\n");
	for (x = 0; x < MEM_SIZE; x += 4) {
		if (!(x&0xFF)) {
			printf("%u...\r", x);
			fflush(stdout);
		}
		gen_write(x, read_rng(4), 4);		// write and read back
		gen_read(x, 4);
	}
	printf("\nDone\n");

	// pick a random offset until it doesn't cross a cache line
	printf("Running random traffic...\n");
	for (;;) {
		if (!(lines&0xFF)) {
			printf("%llu...\r", lines);
			fflush(stdout);
		}
		do {
			r = read_rng(4);
			bl = 1+((r>>13)&3);
		} while ((r & 31) > ((r + bl) & 31));

		if (r & 0x80000000) {
			gen_read(r & (MEM_SIZE - 1), bl);
		} else {
			uint32_t v = read_rng(4);
			gen_write(r & (MEM_SIZE - 1), v, bl);
		}
	}
}
