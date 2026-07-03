/*
 * Simple 'hello' program.
 */
#include <cflea.h>

#define USE_BIOS
#define USE_BOOT
#include "cf/lib/time.c"
#include "cf/lib/console.c"
#include "cf/lib/sd.c"
#include "cf/lib/fat16.c"

// benchmark various opcodes
unsigned cpu_cycles(unsigned test)
{
	switch(test) {
		case 0:
			asm {
				FCB $EE
				FCB $EE					// RDTSC
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
				ST $FFFE
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
		case 13:
			asm {
				FCB $EE
				OUT $01
				FCB $EE
				RET
			}
		case 14:
			asm {
				FCB $EE
				LD #$FFFF
				FCB $EE
				NEG
				TAI
				FCB $EE
				LD #$FFFF
				DIVB #$11
				FCB $EE
				ADAI
				TIA
				RET
			}
		case 15:
			asm {
				FCB $EE
				ADDB #$FF
				FCB $EE
				RET
			}
		case 16:
			asm {
				FCB $EE
				SHL #5
				FCB $EE
				RET
			}
		case 17:
			asm {
				FCB $EE
				ST 2,S
				FCB $EE
				RET
			}
		case 18:
			asm {
				FCB $EE
				SJMP NEXT
NEXT EQU *
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
	"ST $FFFE",
	"LD $FF00",
	"LD $F000",
	"TSA",
	"OUT $01",
	"DIV $FFFF/$11",
	"ADDB #$FF",
	"SHL #5",
	"ST 2,S",
	"SJMP NEXT",
	NULL
};

main()
{
	unsigned y, x, z;
	char str[80];
	printf("Foo bar\n");
	printf("\nCycle counts:\n");
	for (z = x = 0; tests[x]; x++) {
		y = cpu_cycles(x) - z;
		if (x == 0) {
			z = y;
		}
		printf("\t%s: %u\n", tests[x], y);
	}
	printf("FAT16 LBA: 0x%04x%04x\n", fat16_lba[1], fat16_lba[0]);
	c_clrscr();
	c_puts("Cycle counts:\n");
	for (z = x = 0; tests[x]; x++) {
		y = cpu_cycles(x) - z;
		if (x == 0) {
			z = y;
		}
		sprintf(str, "   %s: %u\n", tests[x], y);
		c_puts(str);
	}

	wait_ms(2000);
	asm {
		JMP $F000
	}
}
