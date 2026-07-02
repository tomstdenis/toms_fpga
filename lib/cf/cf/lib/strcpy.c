#ifndef STRCPY_C_
#define STRCPY_C_

#include "cf/lib/tni.h"

strcpy(char *d, char *s)
{
/*
	while (*s) {
		*d++ = *s++;
	}
	*d = 0; 
*/
	asm {
		LD 4,S
?strcat_cpy_entry EQU * strcat provides d so we do not need to load it from the stack
		DEC
		TNI TAR1			* R1 == --d
		LD 2,S				* load s
		DEC
		TNI TAR0			* R0 == --s
?strcpy_top
		TNI INCR0I			* I = ++R0
		LDB I				* load from [R0]
		TNI INCR1I			* I = ++R1
		STB I				* store to [R1]
		SJNZ ?strcpy_top
	}
}


#endif

