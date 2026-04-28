; void ttyClear(void);
;

.ALIGN 0x10
:ttyClear
.REG txtmem_hi
.REG txtmem_lo
.REG cnt_hi
.REG cnt_lo
.REG tmp
.PUSHREGS
	
	; txtmem = &video;
	LDI txtmem_hi,<TXTMEM					; video memory
	LDI txtmem_lo,>TXTMEM
	; cnt = 0x800
	LDI cnt_hi,0x08							; 0x800 bytes to write
	LDI cnt_lo,0x00
:TTYCLEARLOOP
	; *txtmem = 0;
	STM 0,txtmem_hi,txtmem_lo
	; ++txtmem;
	INC txtmem_lo,txtmem_lo
	ADC txtmem_hi,txtmem_hi,0
	; --cnt;
	DEC cnt_lo,cnt_lo
	SCC tmp									; store carry in tmp
	NEG tmp,tmp
	ADD cnt_hi,cnt_hi,tmp					; subtract carry from cnt_hi
	; if cnt != 0 then goto TTYCLEARLOOP
	OR tmp,cnt_lo,cnt_hi					; are the remaining byte counter bytes zero?
	JNZ TTYCLEARLOOP
	; ttyMoveXY(0x00, 0x00);
	PUSH 1
	PUSH 2
	LDI 1,0x00
	LDI 2,0x00
	LCALL ttyMoveXY
	POP 2
	POP 1

.POPREGS

	RET
