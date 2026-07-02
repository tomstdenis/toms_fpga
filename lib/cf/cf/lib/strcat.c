#ifndef STRCAT_C_
#define STRCAT_C_

#include "cf/lib/strcpy.c"
#include "cf/lib/tni.h"

strcat(char *d, char *s)
{
/*
	while (*d++);
	--d;
	while (*s) {
		*d++ = *s++;
	}
	*d = 0; 
*/
	// advance to end of d
	asm {
		LDI 4,S					* I == d
?strcat_top
		LDB I
		SJZ ?prep_strcpy		* *d == 0 so we strcpy s to d now
		LEAI 1,I
		SJMP ?strcat_top
?prep_strcpy
		TIA						* A == INDEX
		SJMP ?strcat_cpy_entry
	}
}


#endif

