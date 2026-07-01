// CFLEA Primer25K Boot Loader

/* memory layout


0000..CCFF  -- App space (51.25kByte)
CD00..CDFF  -- Bootloader stack (can be reclaimed by app)
CE00..CFFF  -- Sector buffer (should be left alone if you use USE_BOOT for FAT16 routines)
D000..EFFF  -- boot loader/shell?
F000..F7FF  -- BIOS
F800..FFFF  -- VRAM

*/


asm {
	ORG $D000		* code starts after first sector
	LD #$CE00       * 256 bytes of stack CD00..CDFF
	TAS				* Set stack to top of memory
	CALL main
	JMP $F000
}

#define USE_BIOS
#include <cflea.h>
#include "cf/lib/time.c"
#include "cf/lib/memset.c"
#include "cf/lib/memcmp.c"
#include "cf/lib/memcpy.c"
#include "cf/lib/puts.c"
#include "cf/lib/sd.c"
#include "cf/lib/fat16.c"
#include "cf/lib/hex.c"
#include "cf/lib/getc.c"

// partition 1 is 2048 sectors in
uint16_t sector_op(uint16_t sector[2], uint8_t *data, uint16_t wr_en)
{
	uint16_t off[2];
	off[1] = sector[1] + (((off[0] = sector[0] + fat16_lba[0]) < fat16_lba[0]) ? 1 : 0) + fat16_lba[1];
	sd_sector_op(off, data, 0);
}

boot_app(char *name)
{
	struct fat16_volinfo *fv;
	struct fat16_volinfo fvp;
	unsigned x;

	fv = fvp;
	if (!fat16_initvol(fv, 0xCE00)) {
		puts("BL: Opening "); puts(name); puts("\r\n");
		if (!fat16_fopen(fv, name)) {
			// load file memory
			puts("BL: Reading contents\r\n");
			x = fat16_fread(fv, 0, 0xCD00);
			puts("Read 0x"); print_hex_word(x); puts(" bytes\r\n");
			asm {
				LD $0			* load entry point
				TAS				* assume stack starts at app start
				CLR
				ST $0			* zero ?temp
				TSA				* restore ACC
				IJMP			* jump to it
			}
		} else {
			puts(name); puts(" not found.\n\r");
		}
	} else {
		puts("Could not init FAT16 Volume.\r\n");
	}
}

main()
{
   sd_init();
   if (!sd_reset()) {
	   puts("BL: Initing FAT16...\n\r");
//	   boot_app("/COMMAND.CF");
	   boot_app("/HELLO.CF");
   } else {
	   puts("Could not init SD card.\r\n"); 
   }
}
