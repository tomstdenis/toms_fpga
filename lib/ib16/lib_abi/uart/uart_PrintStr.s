; void PrintStr(char *p);
;

.ALIGN 0x10
:PrintStr
.REG p_hi
.REG p_lo
.REG tmp
.REG uart_hi
.REG uart_lo
.PUSHREGS

	LDI uart_hi,<UART_ADDR
	LDI uart_lo,>UART_ADDR
:PRINTSTRLOOP
	LDM tmp,p_hi,p_lo				; load char
	JZ PRINTSTRDONE			; exit if NUL
	INC p_lo,p_lo
	JNC PRINTSTRNC
	INC p_hi,p_hi				; carry
:PRINTSTRNC
	STM tmp,uart_hi,uart_lo				; print it
	JMP PRINTSTRLOOP
:PRINTSTRDONE

.POPREGS
	RET
