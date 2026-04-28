; void ttyGets(char *p);
;

; gets
.ALIGN 0x10
:ttyGets
; Input:
;	- r15:r14 uart
;	- r13:r12 destination for string
; Output:
;   - None
.REG p_hi
.REG p_lo
.REG tmp
.REG cr
.REG nl
.REG bs
.REG cnt
.REG uart_hi
.REG uart_lo

.PUSHREGS

	LDI uart_hi,<UART_ADDR		; address of UART MMIO
	LDI uart_lo,>UART_ADDR
	LDI nl,0x0A					; newline and cr to compare against
	LDI cr,0x0D
	LDI bs,0x08					; backspace
	LDI cnt,0x00				; how many bytes we stored
:GETSLOOP
	LDM tmp,uart_hi,uart_lo		; read uart
	CMPEQ tmp,bs				; backspace?
	JC GETSBS					; handle backspace
	CMPEQ tmp,nl				; compare to linefeed
	JC GETSDONE
	CMPEQ tmp,cr				; compare to carriage return
	JC GETSDONE
	; store byte in buffer
	LCALL ttyPutc
	STM tmp,p_hi,p_lo			; store the byte
	INC p_lo,p_lo				; increment pointer
	ADC p_hi,p_hi,0				; add r0(0) + carry to p_hi
	INC cnt,cnt					; how many bytes we stored
	JMP GETSLOOP
:GETSBS							; handle backspace
	AND cnt,cnt,cnt				; is count zero?
	JZ GETSLOOP					; no bytes in buffer
	DEC cnt,cnt					; decrement counter
	DEC p_lo,p_lo
	JNC GETSBSNC
	DEC p_hi,p_hi
:GETSBSNC
	PUSH 1						; example of calling inside a function, here we push the fixed registers 
	MOV 1,tmp
	LCALL ttyPutc				; print backspace
	LDI 1,0x20
	LCALL ttyPutc				; print space
	LDI 1,0x08					; print another backspace to move backwards
	LCALL ttyPutc				; print backspace
	POP 1
	JMP GETSLOOP				; back to reading next char
:GETSDONE
	STM 0,p_hi,p_lo				; store NUL 

.POPREGS

	RET
