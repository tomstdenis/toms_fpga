#ifndef STRLEN_C_
#define STRLEN_C_

#include "cf/lib/tni.h"

unsigned strlen(char *p)
{
/*
	unsigned x;
	while (*p++) {
		++x;
	}
	return x;
*/
	asm {
		LDI 2,S				* index == p
?strlen_top
		LDB I				* load [INDEX]
		SJZ ?strlen_out
		LEAI 1,I			* I = I + 1
		SJMP ?strlen_top
?strlen_out
		TIA					* A = I
		SUB 2,S				* A -= p which should be how far I advanced
	}
}

#endif
