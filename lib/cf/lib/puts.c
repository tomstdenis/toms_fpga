#ifndef PUTS_C_
#define PUTS_C_

puts(char *s)
{
	asm {
		LD 2,S
		TAI
?puts_top EQU *
		LD I
		SJZ ?puts_end
		OUT $00
		LEAI 1,I
		SJMP ?puts_top
?puts_end EQU *
	}
}

#endif
