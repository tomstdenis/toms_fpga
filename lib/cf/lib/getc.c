#ifndef GETC_C_
#define GETC_C_

#include "lib/mem.h"

int getch() {
	asm {
		IN $00
	}
}

// borrow from the SD space
#define getc_echo *((unsigned char*)getc_echo_addr)

int getc() {
	asm {
?getc_top EQU *
		IN $00
		INC
		SJZ ?getc_top
		DEC
		TAI
		ANDB getc_echo_addr
		SJZ ?getc_no_echo
		TIA
		OUT $00
?getc_no_echo EQU *
		TIA
	}
}

#endif
