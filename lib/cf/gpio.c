//#define DEBUG

#include <cflea.h>
#include "lib/console.c"
#include "lib/time.c"
#include "lib/port.c"
#include "lib/spi.c"
#include "lib/sd.c"

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

unsigned char sec[512];

main(void)
{
	unsigned x, y, sector[2];
	
	memset(sec, 0, sizeof(sec));
	printf("\n\nSD Card GPIO demo\n");
	// pinout for the PMOD SD card board;	
//sd_init(int port, int cs, int sck, int miso, int mosi)
	sd_init(0, 3, 0, 1, 2);
	x = sd_reset();
	printf("sd_reset() == %x, %d, %d, %04x, %04x, %04x, %04x\n", x, sd_is_init, sd_is_hc, spi_sck_mask_ds, spi_miso_mask_ds, spi_mosi_mask_ds, spi_cs_mask_ds);
	if (!x) {
		printf("csd == ");
		for (x = 0; x < 16; x++) {
			printf("%02x ", sd_csd[x]);
		}
		printf("\nsd_sectors[] == { %04x, %04x }\n", sd_sectors[1], sd_sectors[0]);
		sector[0] = 5; sector[1] = 0x0000;
		x = sd_read_sector(sector, sec);
		if (!x) {
			printf("Read sector #%04x%04x...:\n\t", sector[1], sector[0]);
			for (x = 0; x < 512; x++) {
				printf("%02x ", sec[x]);
				if (((x+1)&15) == 0) {
					printf("\n\t");
				}
			}
			printf("\n");
		} else {
			printf("Error reading sector#%04x%04x...%x\n", sector[1], sector[0], sd_read_error);
		}
	}
	asm {
		LD #$F000
		IJMP
	}
}


			
