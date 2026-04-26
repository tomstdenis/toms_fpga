;
; clear screen
.ALIGN 0x10
:ttyClear
	PUSH 15
	PUSH 14
	PUSH 13
	PUSH 12
	PUSH 11
	PUSH 2
	PUSH 1
	
	LDI 15,<TXTMEM				; video memory
	LDI 14,>TXTMEM
	LDI 13,0x08					; 0x800 bytes to write
	LDI 12,0x00
:TTYCLEARLOOP
	STM 0,15,14
	INC 14,14
	ADC 15,15,0
	DEC 12,12
	SCC 11						; store carry in 11
	NEG 11,11
	ADD 13,13,11				; subtract carry from 13
	OR 11,12,13					; are the remaining byte counter bytes zero?
	JNZ TTYCLEARLOOP
	; set cursor to 0,0
	LDI 1,0x00
	LDI 2,0x00
	LCALL ttyMoveXY
	
	POP 1
	POP 2
	POP 11
	POP 12
	POP 13
	POP 14
	POP 15
	RET
