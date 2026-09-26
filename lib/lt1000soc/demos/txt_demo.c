#include "lt1000.h"

void main(void)
{
	uint32_t x;
	char buf[32];
	
	txt_init();
	txt_puts("Hello world!\n");
	txt_cursor(0xFFFFFFFF, 0xFFFFFFFF, 0x80 | (1 << 5)); // bright green
	txt_puts("LT1000 Lives!\n\r");
	txt_cursor(0xFFFFFFFF, 0xFFFFFFFF, (1 << 4)); // blue
	fprintf(stderr, "Screen config: %d x %d\nEnter your name: ", TXT_COLS, TXT_ROWS);
	txt_cursor(0xFFFFFFFF, 0xFFFFFFFF, (1 << 6) | (1<<2) | (1<<1)); // red on yellow
	txt_gets(buf);
	txt_cursor(0xFFFFFFFF, 0xFFFFFFFF, 0x70); // white
	fprintf(stderr, "\nHello %s\n", buf);
	delay_ms(2000);
	return;
	txt_clrscr();	
	for (x = 0; x < 100; x++) {
		fprintf(stderr, "line %d\n", x); fflush(stderr);
		delay_ms(250);
	}
	
	getch();
}
