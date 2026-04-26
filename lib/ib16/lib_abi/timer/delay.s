.EQU TIMER_ADDR 0xFFF9

; delay 0..255 milliseconds
; void timerDelay(uint8_t ms);

.ALIGN 0x10
:timerDelay
.IREG ms_delay
.REG timer_hi
.REG timer_lo
.REG timer_dat
.PUSHREGS
	
	LDI timer_hi,<TIMER_ADDR			; set r15:r14 to pointer to the timer
	LDI timer_lo,>TIMER_ADDR
	STM 0,timer_hi,timer_lo				; write anything to reset the timer to 0
:TIMERDELAYLOOP
	LDM timer_dat,timer_hi,timer_lo		; read timer
	XOR timer_dat,timer_dat,ms_delay	; compare to how long we're meant to wait
	JNZ TIMERDELAYLOOP					; loop until it matches

.POPREGS
	RET
