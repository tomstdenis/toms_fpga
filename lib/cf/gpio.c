#include <cflea.h>
#include "lib/console.c"
#include "lib/time.c"
#include "lib/port.c"

main(void)
{
	unsigned val[4], x, y;
	unsigned char name[11], str[80];
	
	for (x = 0; x < 4; x++) val[x] = 1 + 2 * x;
	
	c_clrscr();
	c_boxmsg(10, 8, "Box text goes here eh");
	c_boxquery(5, 3, "Hello what's your name:", name, 10);
	sprintf(str, "Hello '%s'", name);
	c_boxmsg(15, 15, str);
	wait_ms(5000);
	c_gotoxy(0, 0);
	y = 0;
	c_clrscr();
	for (;;) {
		sprintf(str, "vals: %2x, %2x, %2x, %2x\n", val[0], val[1], val[2], val[3]);
		c_boxmsg(3, 0, str);
		sprintf(str, "Loops: %d", ++y);
		c_boxmsg(40, 5, str); 
		wait_ms(250);
		for (x = 0; x < 4; x++) {
			val[x] = ((val[x] << 1) | (val[x] >> 7)) & 0xFF;
			outport(x, val[x]);
		}
	}
}


			
