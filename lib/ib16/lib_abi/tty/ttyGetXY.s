; uint16_t ttyGetXY(void)
;

.ALIGN 0x10
:ttyGetXY
.IREG x
.IREG y
.REG tty_hi
.REG tty_lo
.PUSHREGS

	; tty = &tty_xy;
	LDI tty_lo,>TTY_XY
	LDI tty_hi,<TTY_XY
	; x = *tty;
	LDM x,tty_hi,tty_lo
	; ++tty;
	INC tty_lo,tty_lo
	ADC tty_hi,tty_hi,0
	; y = *tty;
	LDM y,tty_hi,tty_lo

.POPREGS

	RET
