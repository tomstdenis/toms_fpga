; library functions

; Quickguide
; Typically things expect the UART in r15:r14 and user pointers in r13:r12
; Single values are passed in/returned via r1

; *** OUTPUT ***
; PrintHexByte: Prints 'r1' in hex to r15:r14
; PrintNewLine: Prints a \n\r to r15:r14
; PrintStr:     Prints a NUL terminated string pointed to by r13:r12 to r15:r14

; *** INPUT ***
; ReadHexByte:  Reads a hex byte (upper or lower case) from R15:R14 into r1
; ReadStr:		Reads a string (terminated by \r or \n) from R15:R14 into R13:R12, handles backspace(08) properly.



; *** CODE ***
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
	PUSH 7
	LDI 1,0x00				; clear r1
	LDI 2,2					; read two nibbles
	LDI 3,0x30				; '0'
	LDI 4,0x09				; for comparison to to 9
	LDI 5,0x07
	LDI 7,0x0F				; for masking
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
	AND 6,6,7
	OR 1,1,6				; store nibble
:READHEXBYTEEND
	DEC 2,2					; decrement nibble counter
	JZ READHEXBYTEDONE		; 
	SWAP 1,1				; flip it to the top of r1
	JMP READHEXBYTELOOP
:READHEXBYTEDONE
	POP 7
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
	SRES 1					; set read increment flag
:PRINTSTRLOOP
	LDM 1,13,12				; load char
	JZ PRINTSTRDONE			; exit if NUL
	STM 1,15,14				; print it
	JMP PRINTSTRLOOP
:PRINTSTRDONE
	SRES 0					; disable read increment flag
	POP 1
	RET

; *** ReadStr ***
; Reads a \n and/or \r terminated into memory as a NUL terminated string
; Input:
;	- r15:r14 uart
;	- r13:r12 destination for string
; Output:
;   - None
.ALIGN 0x10
:ReadStr
	PUSH 1
	PUSH 2
	PUSH 3
	PUSH 4
	PUSH 5
	PUSH 13
	PUSH 12
	LDI 2,0x0A				; newline and cr to compare against
	LDI 3,0x0D
	LDI 4,0x08				; backspace
	LDI 5,0x00				; how many bytes we stored
:READSTRLOOP
	LDM 1,15,14				; read uart
	CMPEQ 1,4				; backspace?
	JC READSTRBS			; handle backspace
	CMPEQ 1,2				; compare to linefeed
	JC READSTRDONE
	CMPEQ 1,3				; compare to newline
	JC READSTRDONE
	; store byte in buffer
	STM 1,15,14				; echo back
	STM 1,13,12				; store the byte
	INC 12,12				; increment pointer
	ADC 13,13,0				; add r0(0) + carry to 13
	INC 5,5					; how many bytes we stored
	JMP READSTRLOOP
:READSTRBS					; handle backspace
	AND 5,5,5				; is count zero?
	JZ READSTRLOOP			; no bytes in buffer
	DEC 5,5					; decrement counter
	DEC 12,12
	JNC READSTRBSNC
	DEC 13,13
:READSTRBSNC
	STM 1,15,14				; print backspace
	LDI 1,0x20
	STM 1,15,14				; print a space to overwrite
	LDI 1,0x08				; print another backspace to move backwards
	STM 1,15,14
	JMP READSTRLOOP			; back to reading next char
:READSTRDONE
	STM 0,13,12				; store NUL 
	POP 12
	POP 13
	POP 5
	POP 4
	POP 3
	POP 2
	POP 1
	RET
	
	
