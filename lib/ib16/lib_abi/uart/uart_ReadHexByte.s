; uint8_t readHexByte(void);
;

.ALIGN 0x10
:readHexByte
.IREG val
.REG bits
.REG zero
.REG nine
.REG seven
.REG mask
.REG tmp
.REG uart_hi
.REG uart_lo

.PUSHREGS

	LDI uart_hi,<UART_ADDR
	LDI uart_lo,>UART_ADDR
	LDI val,0x00				; clear val
	LDI bits,2					; read two nibbles
	LDI zero,0xD0				; -'0'
	LDI nine,0x09				; for comparison to to 9
	LDI seven,0xF9				; -7
	LDI mask,0x0F				; for masking
:READHEXBYTELOOP
	LDM tmp,uart_hi,uart_lo		; read from uart
	STM tmp,uart_hi,uart_lo		; echo back
	ADD tmp,tmp,zero			; r5 = r5 - '0'
	CMPGT tmp,nine				; is it bigger than 9?
	JC READHEXBYTEBIG
	OR val,val,tmp				; store nibble
	JMP READHEXBYTEEND
:READHEXBYTEBIG
	ADD tmp,tmp,seven			; it was bigger than 9 so subtract 7 to go to next
	AND tmp,tmp,mask
	OR val,val,tmp				; store nibble
:READHEXBYTEEND
	DEC bits,bits				; decrement nibble counter
	JZ READHEXBYTEDONE			; 
	SWAP val,val				; flip it to the top of r1
	JMP READHEXBYTELOOP
:READHEXBYTEDONE

.POPREGS
	RET
