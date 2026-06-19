#ifndef GETS_C_
#define GETS_C_

gets(char *s)
{
	asm {
		LD 2,S				* load s
		TAI					* store in INDEX
?gets_top EQU *
		CALL getc
		STB I				* store character
		CMPB #8				* compare to BS
		SJNZ ?gets_bs
		LDB I
		CMPB #10			* newline
		SJNZ ?gets_end
		SJMP ?gets_next
?gets_bs EQU *
		LDB #$20			* echo a space
		OUT $00
		LDB #8				* and then move back
		OUT $00
		SJMP ?gets_top
?gets_next EQU *
		LEAI 1,I			* increment I
		SJMP ?gets_top
?gets_end
		LEAI 1,I
		CLR
		STB I				* store NUL
	}
}

#endif
