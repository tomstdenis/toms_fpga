:ISR
STM 1,15,15			; push r1
LDM 1,15,14			; read from UART
STM 1,15,14			; echo it back
INC 6,6
NOT 6,6
STM 6,13,12			; echo it back
NOT 6,6				; revert r6 back to normal form
LDM 1,15,15			; pop r1
RETI

