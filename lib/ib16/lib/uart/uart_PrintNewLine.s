; *** PrintNewline ***
; Prints out a \n\r
; Input:
; 	- r15:r14 uart data
; Output: None
.ALIGN 0x10
:PrintNewline
	PUSH 1
	LDI 1,0x0A
	STM 1,15,14
	LDI 1,0x0D
	STM 1,15,14
	POP 1
	RET
