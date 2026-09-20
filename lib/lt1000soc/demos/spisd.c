#include <stdint.h>
#include "lt1000.h"

#define INIT_DIV 15
#define OPER_DIV 7

void main(void)
{
	uint8_t buf[512];
	uint32_t x;
	
	// wait for a key to be pressed
	getch();

	if (sd_init(0, INIT_DIV, OPER_DIV) == 1) {
		putstr("SD SPI initialized...");
		puts_hex(sd_sectors, 4);
		putstr(" sectors.\n\r");
		if (sd_sector_op(0, OPER_DIV, 0, buf, 0) == 0) {
			putstr("Sector #0 contents\r\n");
			for (x = 0; x < 512; x++) {
				puts_hex((uint32_t)buf[x] << 24, 1); putch(' ');
				if (!((x+1)&15)) putstr("\r\n");
			}
			if (sd_sector_op(0, OPER_DIV, 1, buf, 1) == 0) {
				putstr("Sector #1 written\r\n");
				if (sd_sector_op(0, OPER_DIV, 1, buf, 0) == 0) {
					putstr("Sector #1 contents\r\n");
					for (x = 0; x < 512; x++) {
						puts_hex((uint32_t)buf[x] << 24, 1); putch(' ');
						if (!((x+1)&15)) putstr("\r\n");
					}
				} else {
					putstr("Error reading sector #1\n\r");
				}
			} else {
				putstr("Error writing sector #1\n\r");
			}
		} else {
			putstr("Error reading sector #0...\r\n");
		}		
	} else {
		putstr("SD SPI failed to initialize.\n\r");
	}

	// jump back to the BIOS
	void (*bios_entry)(void) = (void (*)(void))0x01000000;
	bios_entry();
}
