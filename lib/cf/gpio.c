#include <cflea.h>
#include "lib/console.c"
#include "lib/time.c"

outport(int port, unsigned val)
{
	switch (port) {
		case 0:
			asm {
				LD 2,S
				OUT $01
			}
			break;
		case 1:
			asm {
				LD 2,S
				OUT $02
			}
			break;
		case 2:
			asm {
				LD 2,S
				OUT $03
			}
			break;
		case 3:
			asm {
				LD 2,S
				OUT $04
			}
			break;
	}
}

main(void)
{
	unsigned val[4], x;
	unsigned char name[11], str[80];
	
	for (x = 0; x < 4; x++) val[x] = 1 + 2 * x;
	
	c_clrscr();
	c_boxmsg(10, 8, "Box text goes here eh");
	c_boxquery(5, 3, "Hello what's your name:", name, 10);
	sprintf(str, "Hello '%s'", name);
	c_boxmsg(15, 15, str);
	wait_xms(5000);
	c_gotoxy(0, 0);
	for (;;) {
		sprintf(str, "vals: %x, %x, %x, %x\n", val[0], val[1], val[2], val[3]);
		c_puts(str);
		wait_ms(250);
		for (x = 0; x < 4; x++) {
			val[x] = ((val[x] << 1) | (val[x] >> 7)) & 0xFF;
			outport(x, val[x]);
		}
	}
}


			
