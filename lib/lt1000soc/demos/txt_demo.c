#include "lt1000.h"

void main(void)
{
	uint32_t x;
	
	txt_init();
	txt_puts("Hello world!\n");
	txt_puts("LT1000 Lives!\n\r");
	fprintf(stderr, "Screen config: %d x %d\n", TXT_COLS, TXT_ROWS);
	delay_ms(2000);
	txt_clrscr();	
	for (x = 0; x < 100; x++) {
		fprintf(stderr, "line %d\n", x); fflush(stderr);
		delay_ms(250);
	}
	
	getch();
}
