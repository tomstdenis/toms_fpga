; wait r1 seconds
.ALIGN 0x10
:timerWait
	PUSH 1
	PUSH 2
	ADD 2,1,1			; r2 = 2*r1
	ADD 2,2,2			; r2 = 4*r1
	LDI 1,0xFA			; 250ms
:timerWaitLoop
	LCALL timerDelay
	DEC 2,2
	JNZ timerWaitLoop
	POP 2
	POP 1
	RET
	
	
