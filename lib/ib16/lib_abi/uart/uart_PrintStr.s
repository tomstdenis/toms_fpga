; *** PrintStr ***
; Reads a NUL terminate string and prints to the UART
; Input:
;	- r15:14 uart
; 	- r13:r12 string
; Output
;   - None
.ALIGN 0x10
:PrintStr
	PUSH 1
	PUSH 12
	PUSH 13
:PRINTSTRLOOP
	LDM 1,13,12				; load char
	JZ PRINTSTRDONE			; exit if NUL
	INC 12,12
	JNC PRINTSTRNC
	INC 13,13				; carry
:PRINTSTRNC
	STM 1,15,14				; print it
	JMP PRINTSTRLOOP
:PRINTSTRDONE
	POP 13
	POP 12
	POP 1
	RET
