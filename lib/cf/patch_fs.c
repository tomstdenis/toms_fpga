#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv)
{
	FILE *f;
	unsigned char boot[4096], resv_sec[4096];
	unsigned x, y;
	
	// read boot loader
	f = fopen(argv[2], "rb");
	if (fread(boot+512, 1, 3584, f) != 3584) {
		printf("Couldn't read boot loader...\n");
		return -1;
	}
	fclose(f);
		
	// read resv_sec
	f = fopen(argv[1], "rb");
	if (fread(resv_sec, 1, 4096, f) != 4096) {
		printf("Couldn't read entire reserved sectors...\n");
		return -1;
	}
	fclose(f);
	
	// boot loader is loaded in at 0xE000 and the code starts at 0xE200
	// patch JMP in
	resv_sec[0] = 0xD0;
	resv_sec[1] = 0x00;
	resv_sec[2] = 0xE2; // JMP #$E200
	
	// copy bootloader over
	for (x = 512; x < 4096; x++) {
		resv_sec[x] = boot[x];
	}
	
	// checksum it
	for (x = y = 0; x < 4095; x++) {
		y += resv_sec[x];
	}
	y &= 0xFF;
	resv_sec[4095] = (-y) & 0xFF;
	
	// write resv_sec
	f = fopen(argv[1], "r+");
	fwrite(resv_sec, 1, 4096, f);
	fclose(f);

	return 0;
}
