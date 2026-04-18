.PROG_SIZE 0xF80

; INT address
.EQU INT_ADDR 0xFFFC

; simple ISR
.ORG 0x1E00
:ISR
	LDM 1,13,12					; read interrupt
	AND 2,1,11					; test for RX ready
	JZ ISRNOUART
	LDM 2,15,14
	STM 2,15,14
:ISRNOUART
	STM 1,13,12					; clear (any) interrupts
	RETI

.ORG 0

	; setup ISR
	SRES 4
	LDI 15,<UART_ADDR
	LDI 14,>UART_ADDR			; we want to use the UART in app context too
	LDI 13,<INT_ADDR
	LDI 12,>INT_ADDR
	LDI 11,0x01
	STM 11,13,12				; enable uart IRQ
	SRES 0
	
	; setup app
	LDI 14,>UART_ADDR			; we want to use the UART in app context too
	LDI 15,<UART_ADDR	
	LDI 13,<MSG
	LDI 12,>MSG
	LDI 11,<LOOP
	LDI 10,>LOOP
	LDI 1,1						; 1 second
	JMP LOOP
.ALIGN 0x10
:LOOP
	LCALL PrintStr
	LCALL PrintNewline
	LCALL timerWait
	AJMP 11,10
:MSG
.DS 'Hello world!'

	.INC lib/uart/uart.s
