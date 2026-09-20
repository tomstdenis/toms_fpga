#include "lt1000.h"

void main(void)
{
	uint32_t x;
	
	txt_init();
	txt_puts("Hello world!\n");
	txt_puts("LT1000 Lives!\n");
	delay_ms(2000);
	txt_clrscr();	
	for (x = 0; x < 30; x++) {
		fprintf(stderr, "line %d\n\r", x);
		delay_ms(250);
	}
}
