; void ttyMoveXY(uint8_t x, uint8_t y);
;

; move cursor
.ALIGN 0x10
:ttyMoveXY
.IREG x
.IREG y
.REG tty_hi
.REG tty_lo
.PUSHREGS

	; tty = &tty_xy
	LDI tty_lo,>TTY_XY
	LDI tty_hi,<TTY_XY
	; *tty = x;
	STM x,tty_hi,tty_lo
	; ++tty;
	INC tty_lo,tty_lo
	ADC tty_hi,tty_hi,0
	; *tty = y;
	STM y,tty_hi,tty_lo

.POPREGS
	RET
