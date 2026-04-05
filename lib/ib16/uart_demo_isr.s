;ISR for our uart_demo split into a file to test the .INC directive
:ISR
PUSH 1				; push r1
LDM 1,15,14			; read from UART
STM 1,15,14			; echo it back
POP 1				; pop r1
RETI

