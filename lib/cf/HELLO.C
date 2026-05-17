/*
 * Simple 'hello' program.
 */
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

unsigned cpu_cycles(unsigned test)
{
	switch(test) {
		case 0:
			asm {
				FCB $EE
				FCB $EE
				RET
			}
		case 1:							// CALL
			asm {
				FCB $EE
				CALL cpu_cycles_1
cpu_cycles_1
				FCB $EE
				FREE 2		
				RET
			}
		case 2: 						// RET
			asm {
				CALL cpu_cycles_2
				FCB $EE
				RET
cpu_cycles_2
				FCB $EE
				RET
			}
		case 3:							// ADD #FFFF
			asm {
				FCB $EE
				ADD #$FFFF
				FCB $EE
				RET
			}
		case 4:							// LD 0000
			asm {
				FCB $EE
				LD 0000
				FCB $EE
				RET
			}
		case 5:							// ST 8000
			asm {
				FCB $EE
				ST $8000
				FCB $EE
				RET
			}
		case 6:
			asm {
				FCB $EE
				LD 2,S
				FCB $EE
				RET
			}
		case 7:
			asm {
				FCB $EE
				LT
				FCB $EE
				RET
			}
		case 8:
			asm {
				FCB $EE
				CLR
				FCB $EE
				RET
			}
	}
	return 0;
}

unsigned rtl_version(void)
{
	asm {
		FCB $ED
	}
}

vid_mode(unsigned mode)
{
	asm {
		LD 2,S
		OUT $12
	}
}

const char *tests[] = {
	"RDTSC",
	"CALL",
	"RET",
	"ADD #FFFF",
	"LD 0000",
	"ST 8000",
	"LD 2,S",
	"LT",
	"CLR",
	NULL
};

main()
{
	unsigned y, x, z;
	char buf[64];
	printf("\nCycle counts:\n");
	for (z = x = 0; tests[x]; x++) {
		y = cpu_cycles(x) - z;
		if (x == 0) {
			z = y;
		}
		printf("\t%s: %u\n", tests[x], y);
	}
	y = 0;


 	memset(vidmem, 0, 2048);
	vid_mode(1);
	for (x = 0; x < 2048; x++) {
		vidmem[x] = x;
	}
	for (x = 0; x < 25 * 4; x++) {
		wait_ms(250);
	}
	vid_mode(0);
	memset(vidmem, 0, 2048);
	for (;;) {
		wait_ms(33);
		x = cpu_cycles(0);
		z = rtl_version();
		sprintf(buf, "Tom was here! %5u times, %5u cycles per call, top: %02x, core: %02x", ++y, x, z >> 8, z & 255);
		strcpy(vidmem, buf);
		strcpy(vidmem+80, buf);
		strcpy(vidmem+160, buf);
	}
}
