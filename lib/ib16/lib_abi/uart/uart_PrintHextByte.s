; void PrintHexByte(uint8_t val);
;

.ALIGN 0x10
:PrintHexByte
.REG val
.REG mask
.REG nine
.REG zero
.REG chra
.REG tmp
.REG uart_hi
.REG uart_lo
.PUSHREGS

	LDI uart_hi,<UART_ADDR
	LDI uart_lo,>UART_ADDR
	LDI mask,0x0F					; for masking a nibble
	LDI nine,0x09					; for testing for >9
	LDI zero,0x30					; '0'
	LDI chra,0x37					; 'A' - 0x0A 

; get top nibble
	SWAP tmp,val					; get top nibble in bottom of tmp
	AND tmp,tmp,mask				; mask nibble
	CMPGT tmp,nine					; is it >9?
	JC PRINTHEXBYTE1H
	ADD tmp,tmp,zero				; it's 0-9 so add '0' and print
	JMP PRINTHEXBYTE2
:PRINTHEXBYTE1H
	ADD tmp,tmp,chra				; it was 10..15
:PRINTHEXBYTE2
	STM tmp,uart_hi,uart_lo			; print the char
	AND tmp,val,mask				; mask the bottom nibble
	CMPGT tmp,nine
	JC PRINTHEXBYTE2H
	ADD tmp,tmp,zero
	JMP PRINTHEXBYTEDONE
:PRINTHEXBYTE2H
	ADD tmp,tmp,chra
:PRINTHEXBYTEDONE
	STM tmp,uart_hi,uart_lo

.POPREGS
	RET
