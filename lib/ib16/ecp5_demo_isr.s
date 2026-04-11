;ISR for our uart_demo split into a file to test the .INC directive
:ISR
; Note that r2,r12..r15 are already setup during the init of the app
; read character and compare to ESC
	LDM 3,15,14			; read from UART
	STM 1,13,12			; write int pending back to clear it
	CMPEQ 3,2			; is it the ESC key?
	JNC ISR_END			; it's not ESC so echo it back and write to GPIO0
; it's the ESC key
	LDI 1,0x2A			; *
	STM 1,15,14	
	STM 1,15,14
	STM 1,15,14
	SRES 0x10			; boot into boot rom
:ISR_END
	STM 3,15,14			; echo it back
	RETI
