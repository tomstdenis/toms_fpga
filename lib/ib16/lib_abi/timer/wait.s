; wait in count of seconds
; void timerWait(uint8_t seconds);
.ALIGN 0x10
:timerWait
.IREG cnt
.REG loops
.PUSHREGS

	ADD loops,cnt,cnt		; r2 = 2*r1
	ADD loops,loops,loops	; r2 = 4*r1
	LDI cnt,0xFA			; 250ms
:timerWaitLoop
	LCALL timerDelay
	DEC loops,loops
	JNZ timerWaitLoop

.POPREGS
	RET
	
	
