; print a HEX char in r1
.ALIGN 0x10
:ttyPrintHex
	PUSH 15
	PUSH 14
	PUSH 4
	PUSH 3
	PUSH 2
	PUSH 1
	SWAP 2,1		; r2 = r1 <<< 4
	LDI 3,0x0F		; r3 = 0x0f
	AND 2,2,3		; now r2 = input[7:4]
	AND 3,1,3		; r3 = input[3:0]
	LDI 4,0x0A
	CMPLT 2,4		; is first nibble below ten
	JNC PHEXFNA
	; less then 10 so add '0'
	LDI 4,0x30
	ADD 1,2,4			; r1 = r2 + '0'
	JMP PHEXNN
:PHEXFNA
	LDI 4,0x37		; 'A' - 10
	ADD 1,2,4		; r1 = r2 + 'A'
:PHEXNN
	LCALL ttyPutc	; print top nibble
	LDI 4,0x0A
	CMPLT 3,4		; is second nibble below ten
	JNC PHEXFNA2
	; less then 10 so add '0'
	LDI 4,0x30
	ADD 1,3,4			; r1 = r2 + '0'
	JMP PHEXNN2
:PHEXFNA2
	LDI 4,0x37		; 'A' - 10
	ADD 1,3,4		; r1 = r2 + 'A'
:PHEXNN2
	LCALL ttyPutc	; print top nibble
	POP 1
	POP 2
	POP 3
	POP 4
	POP 14
	POP 15
	RET
