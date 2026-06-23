#ifndef PUTS_C_
#define PUTS_C_

#include "cf/lib/io.h"

#ifdef USE_BIOS
#include "cf/lib/bios.h"
putc(unsigned v) {
	asm {
		JMP PUTC
	}
}

puts(char *s) {
	asm {
		JMP PUTS
	}
}
#else
putc(unsigned v)
{
	asm {
		LD 2,S
		OUT PORT_UART_DATA
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
		OUT PORT_UART_DATA
		LEAI 1,I
		SJMP ?puts_top
?puts_end EQU *
	}
}
#endif

#endif
