; library functions


; *** PrintHexByte ***
; Prints byte in r1 in hex
; Input: 
;	- r1 byte to print
;	- r15:r14: uart data 
; Output: None

.ALIGN 0x10
:PrintHexByte
	PUSH 2					; save r2
	PUSH 3
	PUSH 4
	PUSH 5
	PUSH 6

	LDI 2,0x0F				; for masking a nibble
	LDI 3,0x09				; for testing for >9
	LDI 4,0x30				; '0'
	LDI 5,0x37				; 'A' - 0x0A 

; get top nibble
	SWAP 6,1				; get top nibble in bottom of 6
	AND 6,6,2				; mask nibble
	CMPGT 6,3				; is it >9?
	JC PRINTHEXBYTE1H
	ADD 6,6,4				; it's 0-9 so add '0' and print
	JMP PRINTHEXBYTE2
:PRINTHEXBYTE1H
	ADD 6,6,5				; it was 10..15
:PRINTHEXBYTE2
	STM 6,15,14				; print the char
	AND 6,1,2				; mask the bottom nibble
	CMPGT 6,3
	JC PRINTHEXBYTE2H
	ADD 6,6,4
	JMP PRINTHEXBYTEDONE
:PRINTHEXBYTE2H
	ADD 6,6,5
:PRINTHEXBYTEDONE
	STM 6,15,14

	POP 6
	POP 5
	POP 4
	POP 3
	POP 2
	RET
	
; *** PrintNewline ***
; Prints out a \n\r
; Input:
; 	- r15:r14 uart data
; Output: None
.ALIGN 0x10
:PrintNewline
	PUSH 1
	LDI 1,0x0A
	STM 1,15,14
	LDI 1,0x0D
	STM 1,15,14
	POP 1
	RET

; *** ReadHexByte ***
; Reads a hex byte in upper case (no error checking because we're serious)
; Input:
;	- r15:14 uart data
; Output:
;	- r1 the byte value
.ALIGN 0x10
:ReadHexByte
	PUSH 2
	PUSH 3
	PUSH 4
	PUSH 5
	PUSH 6
	LDI 1,0x00				; clear r1
	LDI 2,2					; read two nibbles
	LDI 3,0x30				; '0'
	LDI 4,0x09				; for comparison to to 9
	LDI 5,0x07
:READHEXBYTELOOP
	LDM 6,15,14				; read from uart
	STM 6,15,14				; echo back
	SUB 6,6,3				; r5 = r5 - r3
	CMPGT 6,4				; is it bigger than 9?
	JC READHEXBYTEBIG
	OR 1,1,6				; store nibble
	JMP READHEXBYTEEND
:READHEXBYTEBIG
	SUB 6,6,5				; it was bigger than 9 so subtract 7 to go to next
	OR 1,1,6				; store nibble
:READHEXBYTEEND
	DEC 2,2					; decrement nibble counter
	JZ READHEXBYTEDONE		; 
	SWAP 1,1				; flip it to the top of r1
	JMP READHEXBYTELOOP
:READHEXBYTEDONE
	POP 6
	POP 5
	POP 4
	POP 3
	POP 2
	RET

; *** PrintStr ***
; Reads a NUL terminate string and prints to the UART
; Input:
;	- r15:14 uart
; 	- r13:r12 string
; Output
;   - None
.ALIGN 0x10
:PrintStr
	PUSH 1
	PUSH 12
	PUSH 13
	SRES 1					; set read increment flag
:PRINTSTRLOOP
	LDM 1,13,12				; load char
	JZ PRINTSTRDONE			; exit if NUL
	STM 1,15,14				; print it
	JMP PRINTSTRLOOP
:PRINTSTRDONE
	SRES 0					; disable read increment flag
	POP 13
	POP 12
	POP 1
	RET
