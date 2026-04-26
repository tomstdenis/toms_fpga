; Print a newline/cr
.ALIGN 0x10
:ttyPrintCRNL
	PUSH 1
	LDI 1,0x0A
	LCALL ttyPutc
	LDI 1,0x0D
	LCALL ttyPutc
	POP 1
	RET
