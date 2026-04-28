; void ttyPrintCRNL(void);
;

.ALIGN 0x10
:ttyPrintCRNL
.REG c
.PUSHREGS

	LDI c,0x0A
	LCALL ttyPutc
	LDI c,0x0D
	LCALL ttyPutc

.POPREGS
	RET
