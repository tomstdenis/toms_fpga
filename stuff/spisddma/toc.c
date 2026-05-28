#include <stdio.h>
#include <string.h>

int main(void)
{
	FILE *f;
	int x;
	unsigned char ch;
	
	f = fopen("spidmasd.bin", "r");
	printf("#File_format=Hex\n#Address_depth=512\n#Data_width=8\n");
	while (fread(&ch, 1, 1, f) == 1) {
		printf("%02X\n", ch);
	}
	fclose(f);
}
