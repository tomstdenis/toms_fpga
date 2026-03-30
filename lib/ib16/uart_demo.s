.EQU UART_ADDR 0xFFFF
.EQU GPIO_ADDR 0xFFFD

; load up R14:R15 pointing to UART
LDI 14,>UART_ADDR
LDI 15,<UART_ADDR

; load R12:R13 pointing to GPIO
LDI 12,>GPIO_ADDR
LDI 13,<GPIO_ADDR

; R0 = 'A'
LDI 0,0x42
DEC 0,0				; test DEC

; R3:R2:R1 = 0
LDI 1,0x00
LDI 2,0x00
LDI 3,0x00

; R4 = 0
LDI 4,0x00

:LOOP
CALL PRINT
JMP LOOP

.ORG 100
:PRINT
STM 0,15,14			; store 'A' to UART
LDM 3,13,12			; store R1 to GPIO
LDI 5,0x20
:INCLOOP
INC 1,1				; R1 = R1 + 1
ADC 2,2,4			; increment R2 if carry
ADC 3,3,4			; increment R3 if carry
DEC 5,5
JNZ INCLOOP
STM 3,13,12			; store R1 to GPIO
RET
