#ifndef HEX_C_
#define HEX_C_

const char *hexstr = "0123456789ABCDEF";

print_hex_byte(unsigned v) {
	asm {
		LDI #hexstr
		LD 2,S
		SHR #4
		ADAI
		LDB I
		OUT $00

		LDI #hexstr
		LD 2,S
		ANDB #15
		ADAI
		LDB I
		OUT $00
	}
}

print_hex_word(unsigned v) {
	asm {
		LD 2,S
		SHR #8
		PUSHA
		CALL print_hex_byte
		LDB 2,S
		PUSHA
		CALL print_hex_byte
		FREE 4
	}
}

unsigned read_hex()
{
	unsigned r, c, ch, x;
	c = r = 0;
	
	while (c++ < 4) {
		ch = getc();
		r <<= 4;
		for (x = 0; hexstr[x]; x++) {
			if (hexstr[x] == ch) {
				r |= x;
				break;
			}
		}
		if (!hexstr[x]) {
			break;
		}
	}
	return r;
}

#endif
