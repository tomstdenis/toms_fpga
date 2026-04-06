;ISR for our uart_demo split into a file to test the .INC directive
:ISR
	PUSH 1				; push regs
	PUSH 2
	PUSH 15
	PUSH 14
	PUSH 13
	PUSH 12
; Setup ISR context
	LDI 14,>UART_ADDR
	LDI 15,<UART_ADDR
; load R12:R13 pointing to GPIO
	LDI 12,>GPIO0_ADDR
	LDI 13,<GPIO0_ADDR
; read character and compare to ESC
	LDI 2,0x1B			; ESC key
	LDM 1,15,14			; read from UART
	CMPEQ 1,2			; is it the ESC key?
	JNC ISR_END			; it's not ESC so echo it back and write to GPIO0
; it's the ESC key
	LDI 1,0x2A			; *
	STM 1,15,14	
	STM 1,15,14
	STM 1,15,14
	SRES 0x10			; boot into boot rom
:ISR_END
	STM 1,15,14			; echo it back
	STM 1,13,12			; and write to GPIO0
	POP 12
	POP 13
	POP 14
	POP 15
	POP 2
	POP 1				; pop r1
	RETI
