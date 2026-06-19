#ifndef PUTS_C_
#define PUTS_C_

putc(unsigned v)
{
	asm {
		LD 2,S
		OUT $00
	}
}

puts(char *s)
{
	asm {
		LD 2,S
		TAI
?puts_top EQU *
		LDB I
		SJZ ?puts_end
		OUT $00
		LEAI 1,I
		SJMP ?puts_top
?puts_end EQU *
	}
}

#endif
