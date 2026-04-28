; void ttyPrintHex(char c);
;

.ALIGN 0x10
:ttyPrintHex
.REG c
.REG tmp
.REG mask
.REG cmp

	SWAP tmp,c				; tmp = c <<< 4
	LDI mask,0x0F			; mask = 0x0f
	AND tmp,tmp,mask		; now tmp = input[7:4]
	AND mask,1,mask			; mask = input[3:0]
	LDI cmp,0x0A
	CMPLT tmp,cmp			; is first nibble below ten
	JNC PHEXFNA
	; less then 10 so add '0'
	LDI cmp,0x30
	ADD c,tmp,cmp			; r1 = tmp + '0'
	JMP PHEXNN
:PHEXFNA
	LDI cmp,0x37			; 'A' - 10
	ADD c,tmp,cmp			; r1 = tmp + 'A'
:PHEXNN
	LCALL ttyPutc			; print top nibble
	LDI cmp,0x0A
	CMPLT mask,cmp			; is second nibble below ten
	JNC PHEXFNA2
	; less then 10 so add '0'
	LDI cmp,0x30
	ADD c,mask,cmp			; r1 = tmp + '0'
	JMP PHEXNN2
:PHEXFNA2
	LDI cmp,0x37			; 'A' - 10
	ADD c,mask,cmp			; r1 = tmp + 'A'
:PHEXNN2
	LCALL ttyPutc			; print top nibble
.POPREGS
	RET
