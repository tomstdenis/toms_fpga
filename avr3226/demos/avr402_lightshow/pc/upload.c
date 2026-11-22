#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <errno.h>
#include <inttypes.h>

/*
 * Encodes `num_pixels` of 0x00RRGGBB values into a packed 1-to-3 SPI bitstream.
 * - Enforces (R + G + B) <= max_rgb_sum by repeatedly scaling by 15/16.
 * - Outputs GRB byte order, MSB-first, 3 SPI bits per LED bit (0b100 / 0b110).
 * - `out` must have a capacity of at least `num_pixels * 9` bytes.
 */
void encode_ws2812_spi_stream(const uint32_t *pixels,
                              size_t num_pixels,
                              uint32_t max_rgb_sum,
                              uint8_t *out) {
    size_t out_bytes = num_pixels * 9;
    for (size_t i = 0; i < out_bytes; i++) {
        out[i] = 0;
    }

    size_t bit_cursor = 0;

    for (size_t p = 0; p < num_pixels; p++) {
        uint32_t px = pixels[p];
        uint32_t r = (px >> 16) & 0xFFu;
        uint32_t g = (px >> 8) & 0xFFu;
        uint32_t b = px & 0xFFu;

        // Limit total channel sum to stay within power/current budget
        if (max_rgb_sum > 0) {
            while ((r + g + b) > max_rgb_sum) {
                r = (r * 15u) / 16u;
                g = (g * 15u) / 16u;
                b = (b * 15u) / 16u;
            }
        }

        // WS2812 expects G, then R, then B
        uint8_t grb[3] = { (uint8_t)g, (uint8_t)r, (uint8_t)b };

        for (int ch = 0; ch < 3; ch++) {
            uint8_t val = grb[ch];
            for (int bit = 7; bit >= 0; bit--) {
                uint8_t led_bit = (val >> bit) & 0x01u;
                // 1 -> 0b110 (6), 0 -> 0b100 (4)
                uint8_t sym = led_bit ? 0x06u : 0x04u;

                // Emit the 3 bits of `sym` (MSB first: bit 2 down to bit 0)
                for (int s = 2; s >= 0; s--) {
                    if ((sym >> s) & 0x01u) {
                        out[bit_cursor >> 3] |= (uint8_t)(0x80u >> (bit_cursor & 7u));
                    }
                    bit_cursor++;
                }
            }
        }
    }
}

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

void load_rgb(char *name, uint32_t *leds, uint32_t max)
{
    FILE *f;

    f = fopen(name, "r");
    if (f) {
        while (max-- && fscanf(f, "%"SCNx32"\n", leds) == 1) {
            ++leds;
        }
        fclose(f);
    } else {
        printf("couldn't open file '%s'\n", name);
        exit(-1);
    }
}

uint8_t serial_write(int fd, int out)
{
    uint8_t b;
    int r, tries = 0;

    // try to write byte 
    if (out >= 0) {
top:    
        b = out;
        r = write(fd, &b, 1);
        if (r != 1) {
            if (tries < 16) {
                ++tries;
                goto top;
            }
            printf("Timed out writing 0x%x\n", out);
            exit(-1);
        }
    }

    // look for ack
	tries = 0;
acktop:
	b = 0;
	r = read(fd, &b, 1);
	if (r == 1 && (b == out)) {
		return b;
	} else {
		if (tries < 16) {
			++tries;
			goto acktop;
		}
		printf("Timed out reading 0x%x\n", out);
		exit(-1);
	}
    return 0;
}

uint8_t serial_read(int fd, int in)
{
    uint8_t b;
    int r, tries = 0;

    // look for ack byte
	tries = 0;
acktop:
	b = 0;
	r = read(fd, &b, 1);
	if (r == 1 && (b == in)) {
		return b;
	} else {
		if (tries < 16) {
			++tries;
			goto acktop;
		}
		printf("Timed out reading 0x%x\n", in);
		exit(-1);
	}
    return 0;
}

int main(int argc, char **argv)
{
    uint32_t leds[128], nleds, addr, x, y;
    uint8_t buffer[1024];
    int frame, nextframe, delay, maxpower = 3*64;

    if (argc < 8) {
        printf("%s: /dev/tty${device} leds RGBfile frame nextframe delay maxpower\n", argv[0]);
        return 0;
    }

    // load RGB data and produce packet stream
    memset(buffer, 0, sizeof buffer);
    memset(leds, 0, sizeof leds);
    nleds             = atoi(argv[2]);
    maxpower          = atoi(argv[7]);
    if (nleds >= 113) {
        printf("Too many LEDs specified.\n");
        exit(-1);
    }
    load_rgb(argv[3], leds, nleds);
    encode_ws2812_spi_stream(leds, nleds, maxpower, buffer);
 
    // store sequencing data.
    frame             = atoi(argv[4]);
    nextframe         = atoi(argv[5]);
    delay             = atoi(argv[6]);
    buffer[9*nleds]   = nextframe;
    buffer[9*nleds+1] = delay;

    // stream it out
    printf("Opening serial port...\n");
    fd = open(argv[1], O_RDWR | O_NOCTTY);
    if (fd < 0) { perror("Open port"); return 1; }
    set_interface_attribs(B9600);
	tcflush(fd, TCIOFLUSH);

	// send initial prog byte
	serial_write(fd, 0x55); // write out (and get back 0x55)
	serial_read(fd, 0x56);  // expect an additional 0x56 ack

    // write out frame
    addr = (uint32_t)frame << 10;

    for (x = 0; x < 32; x++) {
        printf("Writing page: %4d / 32...", x);
        fflush(stdout);
        // start writing address
        serial_write(fd, (addr >> 16) & 0xFF);
        serial_write(fd, (addr >> 8) & 0xFF);
        serial_write(fd, (addr) & 0xFF);
        for (y = 0; y < 32; y++) {
			printf("%02x ", buffer[x*32+y]);
			fflush(stdout);
            serial_write(fd, buffer[x*32+y]);
        }
        // wait for eeprom
        printf(", waiting for eeprom ACK...");
		serial_read(fd, 0x57);  // expect an EEPROM ACK
        printf("done\n");

        addr += 32;
    }
    printf("\nDone\n");

    // write out release
    serial_write(fd, 0xFF);
    serial_write(fd, 0xFF);
    serial_write(fd, 0x00);

    close(fd);
}
