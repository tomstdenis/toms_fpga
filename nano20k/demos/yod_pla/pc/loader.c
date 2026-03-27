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

#define PINS 8
#define TERMS 16
#define W_WIDTH (2 * (PINS + PINS + 3))
#define TOTAL_FUSES (2 * PINS + PINS * TERMS + (1 + W_WIDTH) * TERMS)
#define PGM_BITS (TOTAL_FUSES + 8)

struct fuses {
	uint8_t and_fuses[TERMS * W_WIDTH]; // 0 == select input (in[PINS-1:0], ~in[PINS-1:0], out[PINS-1:0], ~out[PINS-1:0], and, ~and, and_reg, ~and_reg, or, ~or, and_reg[i-1], ~and_reg[i-1])
	uint8_t and_outsel_fuses[TERMS]; // 1 == registered output
	uint8_t or_fuses[PINS * TERMS]; // 1 == select AND[p]
	uint8_t or_outsel_fuses[PINS]; // 1 == registered output
	uint8_t or_invert_fuses[PINS]; // 1 == invert output 
	uint8_t gpio_oe_fuses[PINS]; // 
};

#define AND(x, y) ((x) * W_WIDTH + (y))
#define OR(x, y) ((x) * TERMS + (y))

struct fuses *create_fuse(void)
{
	struct fuses *f;
	
	f = calloc(1, sizeof *f);
	memset(f->and_fuses, 1, sizeof(f->and_fuses));
	memset(f->gpio_oe_fuses+(0*PINS/2), 1, PINS/2);
	return f;
}

uint8_t *generate_bitmap(struct fuses *f)
{
	uint32_t x, y;
	uint8_t *s1, *s2;
	
	s1 = calloc(PGM_BITS, sizeof *s1);
	s2 = calloc(PGM_BITS, sizeof *s2);

	x = 0;
	for (y = 0; y < sizeof (f->and_fuses); y++, x++) {
		s1[x] = f->and_fuses[y];
	}
	for (y = 0; y < sizeof (f->and_outsel_fuses); y++, x++) {
		s1[x] = f->and_outsel_fuses[y];
	}
	for (y = 0; y < sizeof (f->or_fuses); y++, x++) {
		s1[x] = f->or_fuses[y];
	}
	for (y = 0; y < sizeof (f->or_outsel_fuses); y++, x++) {
		s1[x] = f->or_outsel_fuses[y];
	}
	for (y = 0; y < sizeof (f->or_invert_fuses); y++, x++) {
		s1[x] = f->or_invert_fuses[y];
	}
	for (y = 0; y < sizeof (f->gpio_oe_fuses); y++, x++) {
		s1[x] = f->gpio_oe_fuses[y];
	}
	
	// reverse
	for (y = 0; y < PGM_BITS; ) {
		s2[y++] = s1[--x] ? 0x55 : 0xAA;
	}
	free(s1);
	return s2;
}

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

void upload_program(int fd, struct fuses *f)
{
	int x;
	uint8_t *pgm, sum;
	
	printf("Sending %d bit program...\n", PGM_BITS);
	pgm = generate_bitmap(f);
	sum = 0;
	for (x = 0; x < PGM_BITS; x++) {
		printf("bit...%d\n", x);
		sum = sum * 3 + pgm[x];
		if (write(fd, &pgm[x], 1) != 1) {
			printf("Error writing bit %d\n");
			exit(-1);
		}
		tcdrain(fd);
	}
	
	printf("Reading checksum..."); fflush(stdout);
	while (read(fd, &pgm[0], 1) != 1);
	printf("%s\n", pgm[0] == sum ? "correct" : "incorrect");
	free(pgm);
}

int main(int argc, char **argv)
{	
    int fd = open(argv[1], O_RDWR | O_NOCTTY);
    if (fd < 0) { perror("Open port"); return 1; }
    set_interface_attribs(fd, B115200);
	tcflush(fd, TCIOFLUSH);
	
	// in the demo config we use gpio[3:0] as outputs as they're on LEDs
	// use gpio[7:4] as inputs, in particular gpio[7:6] are attached to the nano20k buttons
	struct fuses *f = create_fuse();

	// out[0] = gpio[7]
	f->and_fuses[AND(0, 7*2+0)] = 0; // (recall they come in a, ~a pairs, also 0 means to include
	f->or_fuses[OR(0, 0)] = 1;		// use AND[0]
	
	upload_program(fd, f);
}
