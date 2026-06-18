#ifndef GETC_C_
#define GETC_C_

int getch() {
	asm {
		IN $00
	}
}

int getc() {
	asm {
?getc_top EQU *
		IN $00
		INC
		SJZ ?getc_top
		DEC
	}
}

#endif
