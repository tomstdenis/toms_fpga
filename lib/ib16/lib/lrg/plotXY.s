.ALIGN 0x10
:lrgPlotXY ; plot x(r1),y(r2) with colour r3
	PUSH 15
	PUSH 14
	LCALL lrgGetOfs
	STM 3,15,14
	POP 14
	POP 15
	RET
