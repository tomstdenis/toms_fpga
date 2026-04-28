; void PrintNewline(void);
;

.ALIGN 0x10
:PrintNewline
.REG tmp
.REG uart_hi
.REG uart_lo
.PUSHREGS

	LDI uart_hi,<UART_ADDR
	LDI uart_lo,>UART_ADDR
	LDI tmp,0x0A
	STM tmp,uart_hi,uart_lo
	LDI tmp,0x0D
	STM tmp,uart_hi,uart_lo

.POPREGS
	RET
