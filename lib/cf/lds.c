// spam 32K LDB instructions

#include <stdio.h>

int main(void)
{
	int x;
	
	for (x = 0; x < 65536; x += 2) {
		printf("08\n%02x\n", (x >> 1) & 0xFF);
	}
	return 0;
}
