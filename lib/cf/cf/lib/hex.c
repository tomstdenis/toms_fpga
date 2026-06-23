#ifndef HEX_C_
#define HEX_C_

#include "lib/io.h"

#ifdef USE_BIOS
#include "lib/bios.h"
print_hex_byte(unsigned v) {
	asm {
		JMP PRINT_HEX_BYTE
	}
}

print_hex_word(unsigned v) {
	asm {
		JMP PRINT_HEX_WORD
	}
}

unsigned read_hex(unsigned nib) {
	asm {
		JMP READ_HEX
	}
}
#else
const char hexstr[] = "0123456789ABCDEF";

print_hex_byte(unsigned v) {
	asm {
		LDI #hexstr
		LD 2,S
		SHR #4
		ADAI
		LDB I
		OUT PORT_UART_DATA

		LDI #hexstr
		LD 2,S
		ANDB #15
		ADAI
		LDB I
		OUT PORT_UART_DATA
	}
}

print_hex_word(unsigned v) {
	asm {
		LD 2,S
		SHR #8
		PUSHA
		CALL print_hex_byte
		FREE 2
		LD 2,S
		ANDB #255
		PUSHA
		CALL print_hex_byte
		FREE 2
	}
}

unsigned read_hex(unsigned nib)
{
	unsigned r, c, ch, x;
	c = nib;
	r = 0;
	
	while (c--) {
		ch = getc();
		r <<= 4;
		for (x = 0; hexstr[x]; x++) {
			if (hexstr[x] == ch) {
				r |= x;
				break;
			}
		}
	}
	return r;
}
#endif

#endif
