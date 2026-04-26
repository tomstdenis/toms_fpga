; Put a character including \n and \r
.ALIGN 0x10
:ttyPutc
	PUSH 15
	PUSH 14
	PUSH 13
	PUSH 12
	PUSH 11
	PUSH 10
	PUSH 4
	PUSH 3
	PUSH 2

	; load X, Y
	LDI 15,<TTY_XY
	LDI 14,>TTY_XY
	LDM 2,15,14		; load X
	INC 14,14
	LDM 3,15,14		; load Y
	
	; is the character a bs?
	LDI 4,0x08
	CMPEQ 1,4
	JC PUTC_BS	
	; is the character a \r?
	LDI 4,0x0D		; \r
	CMPEQ 1,4
	JC PUTC_CR
	; is it a \n?
	LDI 4,0x0A		; \n
	CMPEQ 1,4
	JC PUTC_NL
	; regular char
	; compute r13:r12 = TXTMEM + Y * 80 + X using the lookup table
	LDI 13,<TTY_YOFF	; r13:r12 points to the TTY_YOFF table
	LDI 12,>TTY_YOFF
	ADD 4,3,3		; double Y (since our lookup table has 2 bytes per entry)
	ADD 12,12,4		; add 2*Y 
	ADC 13,13,0     ; add carry to 13
	LDM 10,13,12	; r11:r10 == pointer to video memory
	INC 12,12
	LDM 11,13,12
	ADD 10,10,2		; add X to video address
	ADC 11,11,0		; carry
	STM 1,11,10		; store character to video memory
	INC 2,2			; increment X
	LDI 4,0x50		; compare to 80
	CMPEQ 2,4
	JNC PUTC_END	; not at end of line
	LDI 2,0x00		; zero X, now we're basically at PUTC_NL
	JMP PUTC_NL
:PUTC_BS
	OR 2,2,2		; X == 0?
	JZ PUTC_END		; jump to end
	DEC 2,2			; move X backwards
	JMP PUTC_END	; jump to end
:PUTC_NL			; newline	
	INC 3,3			; Y = Y + 1
	LDI 4,0x19		; compare to 25
	CMPEQ 3,4
	JNC PUTC_END		; Y < 25
	LDI 3,0x18		; force Y = 24
	LCALL ttyScroll ; scroll the screen
	JMP PUTC_END
:PUTC_CR			; carriage return
	; reset X
	LDI 2,0x00		; X = 0	
:PUTC_END
	; store X, Y
	STM 3,15,14
	DEC 14,14
	STM 2,15,14
	
	POP 2
	POP 3
	POP 4
	POP 10
	POP 11
	POP 12
	POP 13
	POP 14
	POP 15
	RET
