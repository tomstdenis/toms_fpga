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
	uint8_t and_fuses[TERMS * W_WIDTH];
	uint8_t and_outsel_fuses[TERMS];
	uint8_t or_fuses[PINS * TERMS];
	uint8_t or_outsel_fuses[PINS];
	uint8_t or_invert_fuses[PINS];
	uint8_t gpio_oe_fuses[PINS];
};

#define AND(x, y) ((x) * W_WIDTH + (y))
#define OR(x, y) ((x) * TERMS + ((y))

struct fuse *create_fuse(void)
{
	struct fuse *f;
	
	f = calloc(1, sizeof *f);
	memset(f->and_fuses, 1, sizeof(f->and_fuses));
	memset(f->gpio_oe_fuses+(PINS/2), 1, PINS/2);
	return f;
}

uint8_t *generate_bitmap(struct fuse *f)
{
	uint32_t x, y, z;
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
	for (y = 0; y < sizeof (f->or_invert_fuses); y++, x++) {
		s1[x] = f->or_invert_fuses[y];
	}
	for (y = 0; y < sizeof (f->gpio_oe_fuses); y++, x++) {
		s1[x] = f->gpio_oe_fuses[y];
	}
	
	// reverse
	for (y = 0; y < PGM_BITS; ) {
		s2[y++] = s1[--x];
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
