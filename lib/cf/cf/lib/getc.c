#ifndef GETC_C_
#define GETC_C_

#include "cf/lib/io.h"
#include "cf/lib/mem.h"

#define getc_echo *((unsigned char*)getc_echo_addr)

int getch() {
	asm {
		IN PORT_UART_DATA
	}
}

int getc() {
	asm {
?getc_top EQU *
		IN PORT_UART_DATA
		INC
		SJZ ?getc_top
		DEC
		TAI
		ANDB getc_echo_addr
		SJZ ?getc_no_echo
		TIA
		OUT PORT_UART_DATA
?getc_no_echo EQU *
		TIA
	}
}

#endif
