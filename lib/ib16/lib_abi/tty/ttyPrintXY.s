; ttyPrintXY(uint8_t x, uint8_t y, char c);
;

; print char at 
.ALIGN 0x10
:ttyPrintXY
.REG x
.IREG y
.IREG c
.PUSHREGS

	LCALL ttyMoveXY
	MOV x,c
	LCALL ttyPutc

.POPREGS
	RET
