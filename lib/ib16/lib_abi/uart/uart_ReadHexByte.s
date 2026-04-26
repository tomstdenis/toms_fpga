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
	LDI 3,0xD0				; -'0'
	LDI 4,0x09				; for comparison to to 9
	LDI 5,0xF9				; -7
	LDI 7,0x0F				; for masking
:READHEXBYTELOOP
	LDM 6,15,14				; read from uart
	STM 6,15,14				; echo back
	ADD 6,6,3				; r5 = r5 - r3
	CMPGT 6,4				; is it bigger than 9?
	JC READHEXBYTEBIG
	OR 1,1,6				; store nibble
	JMP READHEXBYTEEND
:READHEXBYTEBIG
	ADD 6,6,5				; it was bigger than 9 so subtract 7 to go to next
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
