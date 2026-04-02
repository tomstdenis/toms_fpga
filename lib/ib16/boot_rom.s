.EQU UART_ADDR 0xFFFF

; ROM starts at 2000
:REBOOT
LDI 14,>UART_ADDR
LDI 15,<UART_ADDR
LDI 0,0
LDI 1,0					; start writing to 0
LDI 2,0x1F				; number of 256 byte pages...
LDI 4,0x5A
:FLUSH
LDM 3,15,14
XOR 3,3,4				; compare to 5A
JNZ FLUSH				; dump any non 5A bytes

:LOOP
LDM 3,15,14				; read from UART
STM 3,15,14				; echo char back
STM 3,1,0				; store 
INC 0,0					; increment base
JNC LOOP
INC 1,1
DEC 2,2					; decrement page counter
JNZ LOOP
SRES 0					; reset flags
LCALL 0					; jump to 0x0000
JMP REBOOT
