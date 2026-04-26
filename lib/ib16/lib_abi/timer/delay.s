; delay 0..255 milliseconds
; void timerDelay(uint8_t ms);

.EQU TIMER_ADDR 0xFFF9

.ALIGN 0x10
:timerDelay
.IREG ms_delay							; how many ms to delay
.REG timer_hi							; Timer high address
.REG timer_lo							; Timer low address
.REG timer_dat							; Timer value read from MMIO
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
