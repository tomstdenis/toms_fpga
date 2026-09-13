#include <stdint.h>
#include "lt1000.h"

void main(void)
{
	uint8_t csd[16], buf[512];
	uint32_t sectors, x;
	
	// wait for a key to be pressed
	getc();

	if (sd_init(0, 15, 7, csd, &sectors) == 1) {
		puts("SD SPI initialized...");
		puts_hex(sectors, 4);
		puts(" sectors.\n\r");
		if (sd_sector_op(0, 7, 0, buf, 0) == 0) {
			puts("Sector #0 contents\r\n");
			for (x = 0; x < 512; x++) {
				puts_hex((uint32_t)buf[x] << 24, 1); putc(' ');
				if (!((x+1)&15)) puts("\r\n");
			}
			if (sd_sector_op(0, 7, 1, buf, 1) == 0) {
				puts("Sector #1 written\r\n");
				if (sd_sector_op(0, 7, 1, buf, 0) == 0) {
					puts("Sector #1 contents\r\n");
					for (x = 0; x < 512; x++) {
						puts_hex((uint32_t)buf[x] << 24, 1); putc(' ');
						if (!((x+1)&15)) puts("\r\n");
					}
				} else {
					puts("Error reading sector #1\n\r");
				}
			} else {
				puts("Error writing sector #1\n\r");
			}
		} else {
			puts("Error reading sector #0...\r\n");
		}		
	} else {
		puts("SD SPI failed to initialize.\n\r");
	}

	// jump back to the BIOS
	void (*bios_entry)(void) = (void (*)(void))0x01000000;
	bios_entry();
}
