; void ttyPutc(char c);
;

; Put a character including \n and \r
.ALIGN 0x10
:ttyPutc
.IREG c
.REG xyptr_hi
.REG xyptr_lo
.REG x
.REG y
.REG tmp
.REG yoffptr_hi
.REG yoffptr_lo
.REG vidmem_hi
.REG vidmem_lo
.PUSHREGS

	; load X, Y
	LDI xyptr_hi,<TTY_XY
	LDI xyptr_lo,>TTY_XY
	LDM x,xyptr_hi,xyptr_lo		; load X
	INC xyptr_lo,xyptr_lo
	LDM y,xyptr_hi,xyptr_lo		; load Y
	
	; is the character a bs?
	LDI tmp,0x08
	CMPEQ c,tmp
	JC PUTC_BS	
	; is the character a \r?
	LDI tmp,0x0D		; \r
	CMPEQ c,tmp
	JC PUTC_CR
	; is it a \n?
	LDI tmp,0x0A		; \n
	CMPEQ c,tmp
	JC PUTC_NL
	; regular char
	; compute ryoffptr_hi:ryoffptr_lo = TXTMEM + Y * 80 + X using the lookup table
	LDI yoffptr_hi,<TTY_YOFF	; ryoffptr_hi:ryoffptr_lo points to the TTY_YOFF table
	LDI yoffptr_lo,>TTY_YOFF
	ADD tmp,y,y		; double Y (since our lookup table has 2 bytes per entry)
	ADD yoffptr_lo,yoffptr_lo,tmp		; add 2*Y 
	ADC yoffptr_hi,yoffptr_hi,0     	; add carry to yoffptr_hi
	LDM vidmem_lo,yoffptr_hi,yoffptr_lo	; rvidmem_hi:rvidmem_lo == pointer to video memory
	INC yoffptr_lo,yoffptr_lo
	LDM vidmem_hi,yoffptr_hi,yoffptr_lo
	ADD vidmem_lo,vidmem_lo,x			; add X to video address
	ADC vidmem_hi,vidmem_hi,0			; carry
	STM c,vidmem_hi,vidmem_lo			; store character to video memory
	INC x,x								; increment X
	LDI tmp,0x50						; compare to 80
	CMPEQ x,tmp
	JNC PUTC_END						; not at end of line
	LDI x,0x00							; zero X, now we're basically at PUTC_NL
	JMP PUTC_NL
:PUTC_BS
	OR x,x,x							; X == 0?
	JZ PUTC_END							; jump to end
	DEC x,x								; move X backwards
	JMP PUTC_END						; jump to end
:PUTC_NL								; newline	
	INC y,y								; Y = Y + 1
	LDI tmp,0x19						; compare to 25
	CMPEQ y,tmp	
	JNC PUTC_END						; Y < 25
	LDI y,0x18							; force Y = 24
	LCALL ttyScroll 					; scroll the screen
	JMP PUTC_END
:PUTC_CR								; carriage return
	; reset X
	LDI x,0x00							; X = 0	
:PUTC_END
	; store X, Y
	STM y,xyptr_hi,xyptr_lo
	DEC xyptr_lo,xyptr_lo
	STM x,xyptr_hi,xyptr_lo

.POPREGS
	RET
