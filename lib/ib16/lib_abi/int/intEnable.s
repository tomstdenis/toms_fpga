; void intEnable(uint8_t int_en);
;

.EQU INTEN_ADDR 0xFFFD

.ALIGN 0x10
:intEnable
.IREG int_en
.REG inten_hi
.REG inten_lo
.PUSHREGS

	LDI inten_hi,<INTEN_ADDR
	LDI inten_lo,>INTEN_ADDR
	STM int_en,inten_hi,inten_lo			; store int enable flags

.POPREGS
	RET
