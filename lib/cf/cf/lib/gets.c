#ifndef GETS_C_
#define GETS_C_

#include "cf/lib/io.h"

gets(char *s)
{
	asm {
		LDI 2,S				* INDEX = s
?gets_top EQU *
		CALL getc
		STB I				* store character
		CMPB #8				* compare to BS
		SJNZ ?gets_bs
		LDB I
		CMPB #10			* newline
		SJNZ ?gets_end
		LEAI 1,I			* increment I
		SJMP ?gets_top
?gets_bs EQU *
		LDB #$20			* echo a space
		OUT PORT_UART_DATA
		LDB #8				* and then move back
		OUT PORT_UART_DATA
		SJMP ?gets_top
?gets_end
		CLR
		STB I				* store NUL
	}
}

#endif
