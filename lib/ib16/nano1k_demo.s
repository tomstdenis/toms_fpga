.EQU UART_ADDR 0xFFFF

	; setup ISR
	SRES 4
	LDI 14,>UART_ADDR			; we want to use the UART in app context too
	LDI 15,<UART_ADDR
	SRES 0
	
	; setup app
	LDI 14,>UART_ADDR			; we want to use the UART in app context too
	LDI 15,<UART_ADDR	
	LDI 13,<MSG
	LDI 12,>MSG
:LOOP
	LCALL PrintStr
	LCALL PrintNewline
	JMP LOOP
:MSG
.DS 'Hello world!'

.INC lib/uart.s

; simple ISR
.ORG 0x1F00
:ISR
	LDM 1,15,14
	STM 1,15,14
	
	RETI
	
