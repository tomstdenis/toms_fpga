#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv)
{
	FILE *f;
	unsigned char boot[8192];
	unsigned x, y;
	
	// read boot loader
	f = fopen(argv[2], "rb");
	if (fread(boot, 1, 8192, f) != 8192) {
		printf("Couldn't read boot loader...\n");
		return -1;
	}
	fclose(f);
	
	// checksum it
	for (x = y = 0; x < 8191; x++) {
		y += boot[x];
	}
	boot[8191] = (-y) & 0xFF;
	
	// write boot loader
	f = fopen(argv[1], "r+");
	fseek(f, 512, SEEK_SET);
	fwrite(boot, 1, 8192, f);
	fclose(f);

	return 0;
}
