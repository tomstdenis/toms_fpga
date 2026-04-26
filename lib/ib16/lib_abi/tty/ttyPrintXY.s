; print char at 
.ALIGN 0x10
:ttyPrintXY
	PUSH 1
	LCALL ttyMoveXY
	MOV 1,3
	LCALL ttyPutc
	POP 1
	RET
