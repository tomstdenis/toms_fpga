; void lrgPlotXY(uint8_t x, uint8_t y, uint8_t col);
;

.ALIGN 0x10
:lrgPlotXY
.REG x_pos					; x/y are inputs but we're going to overwrite r1/r2 by calling lrgGetOfs
.REG y_pos
.IREG col
.PUSHREGS

	LCALL lrgGetOfs			; replaces r1:r2 with offset
	STM col,x_pos,y_pos

.POPREGS

	RET
