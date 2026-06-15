#include <cflea.h>
#include "lib/console.c"
#include "lib/time.c"
#include "lib/port.c"

// pins are setup so 0..3 is the top row (starting next to VCC/GND) and 4..7 are the top row
// PMOD LED works as bottom, top, move over
// so we need to map from 0..7 to 0..1, 0..3 based on the pin to led mapping

unsigned remap(unsigned v)
{
	unsigned t;
	t = 0;
	if (v & (1 << 0)) t |= (1 << 4);
	if (v & (1 << 1)) t |= (1 << 0);

	if (v & (1 << 2)) t |= (1 << 5);
	if (v & (1 << 3)) t |= (1 << 1);

	if (v & (1 << 4)) t |= (1 << 6);
	if (v & (1 << 5)) t |= (1 << 2);

	if (v & (1 << 6)) t |= (1 << 7);
	if (v & (1 << 7)) t |= (1 << 3);

	return (~t) & 0xFF;					// invert since 0 == ON, 1 == OFF
}

main(void)
{
	unsigned val[4], x, y;
	unsigned char name[11], str[80];
	
	c_clrscr();
	outport(1, 0xFF); // turn off all LEDs
	for (;;) {
		for (x = 0; x < 256; x++) {
			outport(0, remap(x));				// output new count to GPIO0
			inport(1, (0x0100<<4));				// toggle the 0th LED of GPIO1
			sprintf(str, "x == %u\n", x);
			c_puts(str);
			wait_ms(250);
		}
	}
	
	for (x = 0; x < 4; x++) val[x] = 1 + 2 * x;
	
	c_clrscr();
	
	// calibrate delay_count for 1ms
	x = delay_calibrate();
	sprintf(str, "loops per ms == %u (%u)", x, delay_loops(x));
	c_puts(str);
	
	c_boxmsg(10, 8, "Box text goes here eh");
	c_boxquery(5, 3, "Hello what's your name:", name, 10);
	sprintf(str, "Hello '%s'", name);
	c_boxmsg(15, 15, str);
	wait_ms(5000);
	c_gotoxy(0, 0);
	y = 0;
	c_clrscr();
	for (;;) {
		sprintf(str, "vals: %2x, %2x, %2x, %2x\n", val[0], val[1], val[2], val[3]);
		c_boxmsg(3, 0, str);
		sprintf(str, "Loops: %5u", ++y);
		c_boxmsg(40, 5, str); 
		wait_ms(250);
		for (x = 0; x < 4; x++) {
			val[x] = ((val[x] << 1) | (val[x] >> 7)) & 0xFF;
			outport(x, val[x]);
		}
	}
}


			
