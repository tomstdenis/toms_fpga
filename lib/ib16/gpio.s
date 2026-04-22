; So I had broken this PMOD on my ECP5 
; this program scans the bits to see what
; can be written successfully or not

.ORG 0x0000
.PROG_SIZE 0x200
.INC lib/uart/uart.s

.EQU GPIO1_ADDR 0xFFFA

	LDI 15,<UART_ADDR
	LDI 14,>UART_ADDR
	LDI 13,<GPIO1_ADDR
	LDI 12,>GPIO1_ADDR
	
	LDI 2,0					; current byte
	LDI 3,1					; current direction
:LOOP
	STM 2,13,12				; write to GPIO
	LDI 1,0x0F				; wait 15ms
	LCALL timerDelay
	LDM 4,13,12				; read from GPIO
	XOR 5,2,4				; compute XOR
	JNZ ERROR				; if it's non zero we have an error
:NEXT
	ADD 2,2,3				; go to next byte
	JNZ LOOP
	NEG 3,3					; reverse direction
	JMP LOOP				; restart 
:ERROR
	; an error so print it out orig,read,xor with comma and newline
	MOV 1,2					; print orig
	LCALL PrintHexByte
	LDI 1,0x2C				; comma
	STM 1,15,14				; print comma
	MOV 1,4					; print read
	LCALL PrintHexByte
	LDI 1,0x2C				; comma
	STM 1,15,14				; print comma
	MOV 1,5					; print xor
	LCALL PrintHexByte
	LCALL PrintNewline
	JMP NEXT
