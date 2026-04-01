.EQU UART_ADDR 0xFFFF
.EQU GPIO_ADDR 0xFFFB

; Setup ISR context
LDI 14,>UART_ADDR
LDI 15,<UART_ADDR

; load R12:R13 pointing to GPIO
LDI 12,>GPIO_ADDR
LDI 13,<GPIO_ADDR

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
INC 1,1				; R1 = R1 + 1
ADC 2,2,4			; addc r2,0
ADC 3,3,4			; addc r3,0
STM 3,13,12			; store R1 to GPIO
RET

; Recall to move this if you enable FASTMEM (to 0x0F80)
.ORG 0x0F00			; IRQ vector (word 0x0F00 == address 0x1E00)
:ISR
STM 0,15,15			; push r0
LDM 0,15,14			; read from UART
STM 0,15,14			; echo it back
LDM 0,15,15			; pop r0
RETI

