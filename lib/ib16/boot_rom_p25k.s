; Primer25k fast boot loader (only echo back the first 256 bytes)
.PROG_SIZE 0x30
.BIN_START F000

.EQU UART_ADDR 0xFFFF   ; Blocking 8N1 230.4K baud UART
.EQU GPIO0_ADDR 0xFFFB
.EQU INT_ADDR 0xFFFC
.EQU INTEN_ADDR 0xFFFD

; ROM starts at F000
.ORG F000
	LDI 0,0					; ensure r0==0

	; clear interrupts
	LDI 15,<INT_ADDR
	LDI 14,>INT_ADDR
	LDI 1,0xFF
	STM 1,15,14				; clear all pending interrupts
	LDI 15,<INTEN_ADDR
	LDI 14,>INTEN_ADDR
	STM 0,15,14				; disable all interrupts
	
	; configure loader
	LDI 14,>UART_ADDR		; R15:R14 points to UART
	LDI 15,<UART_ADDR
	LDI 12,>GPIO0_ADDR
	LDI 13,<GPIO0_ADDR
	LDI 1,0					; start writing to 0
	LDI 4,0x5A				; magic constant we wait for before reading data bytes
	NEG 6,4					; save -0x5A since we don't have a SUB opcode
:FLUSH
	LDM 3,15,14
	CMPEQ 3,4				; compare R3 to R4 (uart byte to 0x5A)
	JNC FLUSH				; dump 
	LDM 2,15,14				; load number of pages from UART

:LOOP
	LDM 3,15,14				; read from UART
	STM 3,15,14				; echo char back
	ADD 5,3,6				; subtract 0x5A to get top nibble
	SWAP 5,5				; put it in the top
	LDM 3,15,14
	STM 3,15,14
	ADD 3,3,6				; subtract 0x5A
	OR 3,3,5				; OR with top half
	STM 3,1,0				; store 
	INC 0,0					; increment base
	JNC LOOP
:ELOOP2						; this is where we test if there's another 256 byte page
	INC 1,1					; increment page number
	NOT 11,1				; invert so we can send it to th LEDs on GPIO0
	STM 11,13,12
	CMPEQ 1,2				; compare page number against page count
	JNC LOOP2				; if we're not there we jump to the 2nd phase where we don't echo back anymore
							; if we get here we're done so we force r0 == 0 and then boot the user app at PC=0000
	XOR 0,0,0				; ensure r0 is zero before boot using app
	SRES 8					; boot user app
:LOOP2						; don't echo back for offset >= 256
	LDM 3,15,14				; read from UART
	ADD 5,3,6
	SWAP 5,5
	LDM 3,15,14
	ADD 3,3,6
	OR 3,3,5
	STM 3,1,0				; store 
	INC 0,0					; increment base
	JNC LOOP2
	JMP ELOOP2
