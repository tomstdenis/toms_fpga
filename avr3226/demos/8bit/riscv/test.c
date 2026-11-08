#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

// MMIO is at the top of memory after FLASH and SRAM
#define MMIO_BASE ((128UL + 128UL) << 10)

// Serial port
volatile unsigned char *serial_out = (unsigned char *)(MMIO_BASE + 0);
volatile unsigned char *serial_in = (unsigned char *)(MMIO_BASE + 1);
volatile unsigned char *serial_in_avail = (unsigned char *)(MMIO_BASE + 2);
volatile unsigned char *serial_display_refresh = (unsigned char *)(MMIO_BASE + 3);
volatile unsigned char *serial_cursor_x = (unsigned char *)(MMIO_BASE + 4);
volatile unsigned char *serial_cursor_y = (unsigned char *)(MMIO_BASE + 5);

static const char *msg = "Hello world from Tom's RISC-V emulator!\n";

static void sputs(const char *s)
{
	while (*s) {
		*serial_out = *s++;			// write one char to the serial port
	}
	*serial_display_refresh = 0;
}

static void sgets(char *p)
{
	for (;;) {
		while (!*serial_in_avail);	// poll for serial in, you could do other work here instead of blocking
		*p = *serial_in;			// reading this is a blocking call but since we already waited it must return immediately
		if (*p == '\n') {
			*p = 0;
			return;
		}
		++p;
	}
}

static int fib(int x)
{
	if (x > 2) {
		return fib(x-1) + fib(x-2);
	} else {
		return 1;
	}
}

static void test_computational_stress() {
	int x, y, z = 50, w = 5, d = 1;
	volatile int delay;
	// render a circle
	while (w) {
		z += d;
		if (z == 150) {
			d = -1;
		} else if (z == 50) {
			--w;
			d = 1;
		}
		for (delay = 0; delay < 50000; delay++);	// add delay only really needed if you emulate on a PC as the attiny3226 will be nowhere near as fast...
		*serial_cursor_x = 0;
		*serial_cursor_y = 0;
		*serial_display_refresh = 0;
		for (y = 0; y < 30; y++) {
			int dy = (y - 15) * (y - 15); // we could do the same trick here as for dx but I want to test the RISC-V MUL instruction
			int dx = (0 - 25) * (0 - 25); // starting (x - 25)^2 term
			int dx_step = -49; // using the fact that the step between successive squares is 2n + 1... (2*-25 + 1 == 49)
			for (x = 0; x < 50; x++) {
				if (abs(dx + dy - z) < 15) { // text mode doesn't allow a lot of resolution so if we fuzz it you get a circle out of this
					*serial_out = '*';
					*serial_out = '*'; // output twice because terminals are usually taller than wider in font
				} else {
					*serial_out = ' ';
					*serial_out = ' ';
				}
				dx += dx_step; // step the x^2 term
				dx_step += 2;  // successive terms have an adder that increases by 2
			}
			*serial_out = '\n';
		}
	}
}
 
int main(void)
{
	int x;
	char buf[128], name[32];
	test_computational_stress();
	for (x = 0; x < 25; x++) {
		sprintf(buf, "100000/%d == %d\n", x, 100000 / x);
		sputs(buf);
	}
	for (;;) {
		sputs(msg);
		for (x = 1; x < 5; x++) {
			sprintf(buf, "fib(%d) == %d\n", x, fib(x));
			sputs(buf);
		}
		sputs("What is your name?\n");
		sgets(name);
		sprintf(buf, "Hello %s, how are you?\n", name);
		sputs(buf);
	}
}
