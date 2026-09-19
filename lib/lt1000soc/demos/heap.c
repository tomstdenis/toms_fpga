#include <stdlib.h>
#include "lt1000.h"

void main(void)
{
	char buf[128];
	void *p;
	
	getch();

	p = malloc(256);
	printf("p == 0x%08x %f\n\r", p, 3.14592);

	void (*bios_entry)(void) = (void (*)(void))0x01000000;
	bios_entry();
}
