; wait r1 seconds
.ALIGN 0x10
:timerWait
	PUSH 1
	PUSH 2
	MOV 2,1
	LDI 1,0xFA
:timerWaitLoop
	LCALL timerDelay
	DEC 2,2
	JNZ timerWaitLoop
	POP 2
	POP 1
	RET
	
	
