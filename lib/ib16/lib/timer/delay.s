.EQU TIMER_ADDR 0xFFF9

; delay r1 ms
.ALIGN 0x10
:timerDelay
	PUSH 15
	PUSH 14
	PUSH 2
	
	LDI 15,<TIMER_ADDR		; set r15:r14 to pointer to the timer
	LDI 14,>TIMER_ADDR
	STM 0,15,14				; write anything to reset the timer to 0
:TIMERDELAYLOOP
	LDM 2,15,14				; read timer
	XOR 2,2,1				; compare to how long we're meant to wait
	JNZ TIMERDELAYLOOP		; loop until it matches
	
	POP 2
	POP 14
	POP 15
	RET
