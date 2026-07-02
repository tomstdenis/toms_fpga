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
#include "cf/lib/strlen.c"
#include "cf/lib/strcat.c"
#include "cf/lib/strcpy.c"
#include "cf/lib/puts.c"
#include "cf/lib/sd.c"
#include "cf/lib/fat16.c"
#include "cf/lib/hex.c"
#include "cf/lib/getc.c"
#include "cf/lib/gets.c"

// partition 1 is FAT16_LBA sectors in
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

shell()
{
	char *cp, cmdline[32];
	char cwd[128];
	char cpy[128];
	
	struct fat16_volinfo *fv;
	struct fat16_volinfo fvp;

	fv = fvp;
	if (!fat16_initvol(fv, 0xCE00)) {
		puts("CFLEA Shell\n\r");

		// start at root
		cwd[0] = '/';
		cwd[1] = 0;
		
		for (;;) {
			puts(cwd); puts(" $");
			gets(cmdline);
			
			if (!memcmp(cmdline, "cd", 2)) {
				// do CD
				strcpy(cpy, cwd);
				strcat(cpy, "/");
				strcat(cpy, cmdline + 3);
				// try to open new CWD
				if (fat16_wpath(fvp, cpy)) {
					// couldn't open
					puts("\nPath "); puts(cpy); puts(" not found or not directory.\n\r");
				} else {
					strcpy(cwd, cpy);
				}
			} else if (!memcmp(cmdline, "dir", 3)) {
				// do dir
				// walk to dir
				if (!fat16_wpath(fv, cwd)) {
					// open dir
					fat16_opendir(fv, D_CLUSTER(fv));
					// walk dir ents
					puts("\n");
					while (!fat16_nextdir(fv)) {
						puts(D_FNAME(fv)); putc('.'); puts(D_EXT(fv)); puts("\n\r");
					}
				}
			} else if (cmdline[0] != '\n') {
				// try to run command
				puts("Not yet.\n\r");
			}
		}
	} else { 
		puts("Couldn't initialize FAT-16\n\r");
	}
}

main()
{
	sd_init();
	if (!sd_reset()) {
		//shell();
		boot_app("/COMMAND.CF");
	} else {
		puts("Could not init SD card.\r\n"); 
	}
}
