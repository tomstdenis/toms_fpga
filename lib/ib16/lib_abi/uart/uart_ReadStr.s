; *** ReadStr ***
; Reads a \n and/or \r terminated into memory as a NUL terminated string
; Input:
;	- r15:r14 uart
;	- r13:r12 destination for string
; Output:
;   - None
.ALIGN 0x10
:ReadStr
	PUSH 1
	PUSH 2
	PUSH 3
	PUSH 4
	PUSH 5
	PUSH 13
	PUSH 12
	LDI 2,0x0A				; newline and cr to compare against
	LDI 3,0x0D
	LDI 4,0x08				; backspace
	LDI 5,0x00				; how many bytes we stored
:READSTRLOOP
	LDM 1,15,14				; read uart
	CMPEQ 1,4				; backspace?
	JC READSTRBS			; handle backspace
	CMPEQ 1,2				; compare to linefeed
	JC READSTRDONE
	CMPEQ 1,3				; compare to newline
	JC READSTRDONE
	; store byte in buffer
	STM 1,15,14				; echo back
	STM 1,13,12				; store the byte
	INC 12,12				; increment pointer
	ADC 13,13,0				; add r0(0) + carry to 13
	INC 5,5					; how many bytes we stored
	JMP READSTRLOOP
:READSTRBS					; handle backspace
	AND 5,5,5				; is count zero?
	JZ READSTRLOOP			; no bytes in buffer
	DEC 5,5					; decrement counter
	DEC 12,12
	JNC READSTRBSNC
	DEC 13,13
:READSTRBSNC
	STM 1,15,14				; print backspace
	LDI 1,0x20
	STM 1,15,14				; print a space to overwrite
	LDI 1,0x08				; print another backspace to move backwards
	STM 1,15,14
	JMP READSTRLOOP			; back to reading next char
:READSTRDONE
	STM 0,13,12				; store NUL 
	POP 12
	POP 13
	POP 5
	POP 4
	POP 3
	POP 2
	POP 1
	RET
