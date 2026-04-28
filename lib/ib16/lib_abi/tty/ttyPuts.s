; void ttyPuts(char *str);
;

; Put a string
.ALIGN 0x10
:ttyPuts
.REG str_hi
.REG str_lo
.REG tmp
.PUSHREGS
	
:TTYPUTSLOOP
	LDM tmp,str_hi,str_lo
	JZ TTYPUTSEND
	LCALL ttyPutc
	INC str_lo,str_lo
	ADC str_hi,str_hi,0
	JMP TTYPUTSLOOP
:TTYPUTSEND

.POPREGS
	RET
