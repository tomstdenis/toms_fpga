#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <errno.h>
#include <inttypes.h>

#define LEDS 16

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

void load_rgb(char *name, uint32_t *leds)
{
    FILE *f;

    f = fopen(name, "r");
    if (f) {
        while (fscanf(f, "%"SCNx32"\n", leds) == 1) {
            ++leds;
        }
        fclose(f);
    }
}

int serial_write(int fd, int out, int in, int retry)
{
    uint8_t b;
    int r, tries = 0;

    // try to write byte 
    if (out >= 0) {
top:    
        b = out;
        r = write(fd, &b, 1);
        if (r != 1) {
            if (retry && tries < 16) {
                ++tries;
                goto top;
            }
            printf("Timed out writing 0x%x\n", out);
            return -1; // failed to write
        }
    }

    // look for ack
    if (in >= 0) {
        tries = 0;
acktop:        
        r = read(fd, &b, 1);
        if (r == 1 && in == b) {
            return 0;
        } else {
            if (tries < 16) {
                ++tries;
                goto acktop;
            }
            printf("Timed out reading 0x%x\n", in);
            return -2;
        }
    }
    return 0;
}

int main(int argc, char **argv)
{
    uint32_t leds[LEDS], addr, x, y;
    uint8_t buffer[1024];
    int frame, nextframe, delay, maxpower = 3*64;

    if (argc < 6) {
        printf("%s: /dev/tty${device} RGBfile frame nextframe delay [maxpower]\n", argv[0]);
        return 0;
    }
    if (argc >= 7) {
        maxpower = atoi(argv[6]);
    }

    // load RGB data and produce packet stream
    load_rgb(argv[2], leds);
    encode_ws2812_spi_stream(leds, LEDS, maxpower, buffer);
 
    // store sequencing data.
    frame            = atoi(argv[3]);
    nextframe        = atoi(argv[4]);
    delay            = atoi(argv[5]);
    buffer[9*LEDS]   = nextframe;
    buffer[9*LEDS+1] = delay;

    // stream it out
    fd = open(argv[1], O_RDWR | O_NOCTTY);
    if (fd < 0) { perror("Open port"); return 1; }
    set_interface_attribs(B9600);
	tcflush(fd, TCIOFLUSH);

    // write out frame
    addr = (uint32_t)frame << 10;

    for (x = 0; x < 32; x++) {
        // start writing address
        serial_write(fd, addr >> 16, 0x54, 1);
        serial_write(fd, (addr >> 8) & 0xFF, -1, 0);
        serial_write(fd, (addr) & 0xFF, 0x55, 0);
        for (y = 0; y < 32; y++) {
            serial_write(fd, buffer[x*32+y], y == 31 ? 0x56 : -1, 0);
        }
        serial_write(fd, -1, 0x57, 1); // read EEPROM ack
        addr += 32;
    }

    // write out release
    serial_write(fd, 0xFF, 0x54, 1);
    serial_write(fd, 0xFF, -1, 0);
    serial_write(fd, 0x00, 0x55, 0);
}