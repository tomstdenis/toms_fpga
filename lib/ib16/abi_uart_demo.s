; simple test of the uart code

.PROG_SIZE 0x200
.INC lib_abi/uart/uart.s

	LDI 3,0x00
; say hello
:LOOP
	LDI 1,<HELLOSTR
	LDI 2,>HELLOSTR
	LCALL PrintStr
	LCALL PrintNewline
; read a string	
	LDI 1,<BUF
	LDI 2,>BUF
	LCALL ReadStr
	LCALL PrintNewline
; print string back out
	LCALL PrintStr
	LCALL PrintNewline
; output count of runs
	LDI 1,<TIMESTR
	LDI 2,>TIMESTR
	LCALL PrintStr
	INC 3,3
	MOV 1,3
	LCALL PrintHexByte
	LDI 1,<TIMESTR2
	LDI 2,>TIMESTR2
	LCALL PrintStr
	LCALL PrintNewline
	JMP LOOP
:HELLOSTR
.DS 'Hello user, please enter a string.'
:TIMESTR
.DS 'We have looped 0x'
:TIMESTR2
.DS ' times.'
:BUF
.DUP 32

