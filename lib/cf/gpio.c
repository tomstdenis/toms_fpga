//#define DEBUG

// if you use a Digilent capable in PMOD0 define this, otherwise undefine
#define SPI_FIXED 

#include <cflea.h>
#include "lib/memcmp.c"
#include "lib/console.c"
#include "lib/time.c"
#include "lib/port.c"
#include "lib/sd.c"
#include "lib/fat16.c"

// pins are setup so 0..3 is the top row (starting next to VCC/GND) and 4..7 are the bottom row
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

   return (~t) & 0xFF;              // invert since 0 == ON, 1 == OFF
}

unsigned char sec[512];

uint16_t sector_op(uint16_t sector[2], uint8_t *data, uint16_t wr_en)
{
	sd_sector_op(sector, data, 0);
}

main(void)
{
   char tmp[32];
   struct fat16_volinfo *fv;
   struct fat16_volinfo fvp;

   fv = fvp;
 
   sd_init();
   if (!sd_reset()) {
	   if (!fat16_initvol(fv, sec)) {
		   printf("Vol info\n\r");
		   printf("fat cluster: %u, root dir cluster: %u, data cluster: %u\r\n",
				fvp.fat_c, fvp.root_dir_c, fvp.data_c);
		   printf("Sec per cluster: %u, num root entries: %u, num fats: %u\r\n",
				fvp.sec_cluster, fvp.no_root, fvp.no_fats);
		   printf("lg2) bpc: %u, bpc2: %u, spc: %u, spc2: %u \r\n",
				fvp.lg2_bpc, fvp.lg2_bpc2, fvp.lg2_spc, fvp.lg2_spc2);
		   fat16_opendir(fv, 0);
		   while ((!fat16_nextdir(fv))) {
			   memset(tmp, 0, 10); memcpy(tmp, D_FNAME(fv), 8); printf("Filename: [%s], ", tmp);
			   memset(tmp, 0, 10); memcpy(tmp, D_EXT(fv), 3); printf("ext: [%s], ", tmp);
			   printf("Filesize: %04x%04x", D_FZ1(fv), D_FZ0(fv));
			   printf("\n\r");
		   }
		   
		   // open /ROOT.TXT
		   if (!fat16_fopen(fv, "/ROOT.TXT")) {
			   memset(tmp, 0, 32);
			   printf("Read %u bytes from /ROOT.TXT\n\r", fat16_fread(fv, tmp, 31));
			   printf("msg == [%s]\r\n", tmp);
		   }
	   } else {
		   printf("Failed to init FAT16 volume...\n");
	   }
   } else {
	   printf("Failed to init card.\n");
   }

end:

   asm {
      LD #$F000
      IJMP
   }
}


         
