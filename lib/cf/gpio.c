#include <cflea.h>

#define vidmem ((unsigned char *)0xF800)

// wait upto 255 ms
wait_ms(unsigned ms)
{
	asm {		
		OUT $11			* clear timer
wait_ms_top
		IN $11			* read timer
		CMP 2,S			* compare to ms 
		JZ wait_ms_top  * wait till ms passes
	}
}

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
	
	for (x = 0; x < 4; x++) val[x] = 1 + 2 * x;
	
	for (;;) {
		wait_ms(250);
		for (x = 0; x < 4; x++) {
			val[x] = ((val[x] << 1) | (val[x] >> 7)) & 0xFF;
			outport(x, val[x]);
		}
	}
}


			
