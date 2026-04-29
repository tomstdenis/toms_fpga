; void ReadStr(char *p);
;

.ALIGN 0x10
:ReadStr
.REG p_hi
.REG p_lo
.REG uart_hi
.REG uart_lo
.REG nl
.REG cr
.REG bs
.REG cnt
.REG tmp
.PUSHREGS

	LDI uart_hi,<UART_ADDR
	LDI uart_lo,>UART_ADDR
	LDI nl,0x0A						; newline and cr to compare against
	LDI cr,0x0D
	LDI bs,0x08						; backspace
	LDI cnt,0x00					; how many bytes we stored
:READSTRLOOP
	LDM tmp,uart_hi,uart_lo			; read uart
	CMPEQ tmp,bs					; backspace?
	JC READSTRBS					; handle backspace
	CMPEQ tmp,nl					; compare to linefeed
	JC READSTRDONE
	CMPEQ tmp,cr					; compare to carriage return
	JC READSTRDONE
	; store byte in buffer
	STM tmp,uart_hi,uart_lo			; echo back
	STM tmp,p_hi,p_lo				; store the byte
	INC p_lo,p_lo					; increment pointer
	ADC p_hi,p_hi,0					; add r0(0) + carry to p_hi
	INC cnt,cnt						; how many bytes we stored
	JMP READSTRLOOP
:READSTRBS							; handle backspace
	AND cnt,cnt,cnt					; is count zero?
	JZ READSTRLOOP					; no bytes in buffer
	DEC cnt,cnt						; decrement counter
	DEC p_lo,p_lo
	JNC READSTRBSNC
	DEC p_hi,p_hi
:READSTRBSNC
	PUSH 1
	MOV 1,tmp
	STM 1,uart_hi,uart_lo			; print backspace
	LDI 1,0x20
	STM 1,uart_hi,uart_lo			; print a space to overwrite
	LDI 1,0x08						; print another backspace to move backwards
	STM 1,uart_hi,uart_lo
	POP 1
	JMP READSTRLOOP					; back to reading next char
:READSTRDONE
	STM 0,p_hi,p_lo					; store NUL 

.POPREGS
	RET
