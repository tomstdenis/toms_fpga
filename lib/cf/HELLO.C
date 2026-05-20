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

// benchmark various opcodes
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
		case 9:
			asm {
				FCB $EE
				ST $F800
				FCB $EE
				RET
			}
		case 10:
			asm {
				FCB $EE
				LD $F800
				FCB $EE
				RET
			}
		case 11:
			asm {
				FCB $EE
				LD $F000
				FCB $EE
				RET
			}
		case 12:
			asm {
				FCB $EE
				TSA
				FCB $EE
				RET
			}
	}
	return 0;
}

// return the TOP and CORE versions 
unsigned rtl_version(void)
{
	asm {
		FCB $ED
	}
}

// set the video mode (0 == text, 1 == LRG)
vid_mode(unsigned mode)
{
	asm {
		LD 2,S
		OUT $12
	}
}

unsigned read_video_status(void)
{
	asm {
		IN $12
	}
}
// wait till start of VGA vsync
wait_vsync(void)
{
// active low so a 0 bit means we're in VSYNC
	asm {
wait_vsync_top
		IN $12
		ANDB #2
		JNZ wait_vsync_top
	}
}

// wait till end of VGA vsync
wait_nvsync(void)
{
	asm {
wait_nvsync_top
		IN $12
		ANDB #2
		JZ wait_vsync_top
	}
}

// wait till start of VGA hsync
wait_hsync(void)
{
// active low HSYNC as well
	asm {
wait_hsync_top
		IN $12
		ANDB #4
		JNZ wait_vsync_top
	}
}

// wait to be in active video (this would be time to update your app logic)
void wait_active_video(void)
{
	asm {
wait_active_top
		IN $12
		ANDB #8
		JZ wait_active_top
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
	"ST $F800",
	"LD $F800",
	"LD $F000",
	"TSA",
	NULL
};

main()
{
	unsigned y, x, z;
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
	for (y = 0; y < 2 * 4; y++) {
		wait_ms(250);
		for (x = 0; x < 2048; x++) {
			vidmem[x] = x + (y * 13);
		}
	}
	vid_mode(0);
	memset(vidmem, 0, 2048);
	for (;;) {
		wait_vsync();
		// we're now in vsync for a bit which also includes time outside of vsync but still in blanking.
		x = cpu_cycles(0);
		z = rtl_version();
		outp1(~(y>>4));				// output to LEDs ...
		sprintf(vidmem, "Tom was here! %5u times, %5u cycles per call, top: %02x, core: %02x", ++y, x, z >> 8, z & 255);
		memcpy(vidmem+80, vidmem, 80);
		memcpy(vidmem+160, vidmem+80, 80);
		wait_nvsync();
/*
		if (y == 500) { // set 250ms WDT that we don't ack 
			asm {
				LDB #$FA
				OUT $13
			}
		}
		// clear the tick counter for some time then stop to trigger the WDT
		if (y < 532) {
			asm {
				OUT $11
			}
		}
*/
	}
}
