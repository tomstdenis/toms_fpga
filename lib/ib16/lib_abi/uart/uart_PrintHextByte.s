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
