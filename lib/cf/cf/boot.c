// CFLEA Primer25K Boot Loader
asm {
	ORG $E200		* code starts after first sector
	LD #$FA00       * 512 bytes of stack
	TAS				* Set stack to top of memory
	CALL main
	JMP $F000
}

#define SD_BIOS
#define SD_NO_WRITE
#include <cflea.h>
#include "lib/time.c"
#include "lib/memset.c"
#include "lib/memcmp.c"
#include "lib/memcpy.c"
#include "lib/puts.c"
#include "lib/sd.c"
#include "lib/fat16.c"
#include "lib/hex.c"
#include "lib/getc.c"

uint16_t sector_op(uint16_t sector[2], uint8_t *data, uint16_t wr_en)
{
	sd_sector_op(sector, data, 0);
}

main()
{
   struct fat16_volinfo *fv;
   struct fat16_volinfo fvp;
   unsigned x;

   fv = fvp;
 
   sd_init();
   if (!sd_reset()) {
	   puts("BL: Initing FAT16...\n\r");
	   if (!fat16_initvol(fv, 0xFC00)) {
		   puts("BL: Opening /COMMAND.CF\r\n");
		   if (!fat16_fopen(fv, "/COMMAND.CF")) {
			   // load file memory
			   puts("BL: Reading contents\r\n");
			   x = fat16_fread(fv, 0, 57344);
			   puts("Read 0x"); print_hex_word(x); puts(" bytes\r\n");
			   asm {
				   LD $0			* load entry point
				   IJMP				* jump to it
			   }
		   } else {
			   puts("COMMAND.CF not found.\n\r");
			   return;
		   }
	   } else {
		   puts("Could not init FAT16 Volume.\r\n");
		   return;
	   }
   } else {
	   puts("Could not init SD card.\r\n");
	   return;
   }
}
