// CFLEA Primer25K Boot Loader
asm {
	ORG $E200		* code starts after first sector
	LD #$F900
	TAS				* Set stack to top of memory
	CALL main
	LD #$F000
	IJMP
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

uint16_t sector_op(uint16_t sector[2], uint8_t *data, uint16_t wr_en)
{
	sd_sector_op(sector, data, 0);
}

main()
{
   struct fat16_volinfo *fv;
   struct fat16_volinfo fvp;

   fv = fvp;
 
   sd_init();
   if (!sd_reset()) {
	   if (!fat16_initvol(fv, 0xF900)) {
		   if (!fat16_fopen(fv, "/COMMAND.CF")) {
			   // load file memory
			   fat16_fread(fv, 0, 57344);
			   asm {
				   CLR
				   IJMP
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
