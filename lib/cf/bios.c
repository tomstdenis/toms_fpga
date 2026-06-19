// CFLEA Primer25K BIOS

asm {
	ORG $F000
topofbios EQU *
	LD  #$FF00				* set stack to the top of video memory - 256 to allow for temps
	TAS
	CALL main
?halt EQU *
	SJMP ?halt
}

#define SPI_FIXED
#define SD_BIOS
#define SD_NO_WRITE
#include <cflea.h>
#include "lib/time.c"
#include "lib/getc.c"
#include "lib/gets.c"
#include "lib/puts.c"
#include "lib/hex.c"
#include "lib/spi.c"
#include "lib/sd.c"

inspect_mem()
{
}

enter_mem()
{
}

serial_upload()
{
}

main() {
	unsigned sector[2];
	unsigned ch;
boot_sd:
	sd_init_fixed();
	puts("\nAttempting to read from SD card\n");
	if (!sd_reset()) {
		// read first 8 sectors (4KB) at 0x0000 and jump there
		sector[1] = 0;
		for (sector[0] = 0; sector[0] < 8; sector[0]++) {
			if (sd_sector_op(sector, 0x0000, 0) != 0) { goto terminal; }
		}
		
		asm {
			CLR
			IJMP
		}
	}
	puts("Failed to init SD card.\n");
terminal:
	// at this point we go interactive
	puts("Monitor:  Press H for help\n");
	for (;;) {
		puts("* ");
		ch = getc();
		switch (ch) {
			case 'H':
				puts("B: Boot SD\nM: Inspect memory\nE: Enter memory\nS: Serial upload\n\n");
				break;
			case 'B':
				goto boot_sd;
			case 'M':
				inspect_mem();
				break;
			case 'E':
				enter_mem();
				break;
			case 'S':
				serial_upload();
			default:
				puts("? UNKNOWN\n");
		}	
	}
}

asm {
endofbios EQU *
}
