.EQU UART_ADDR 0xFFFF
.EQU GPIO_ADDR 0xFFFB

; Setup ISR context
SRES 0x04				; enable ISR context
LDI 14,>UART_ADDR
LDI 15,<UART_ADDR
SRES 0x00				; default context

; load R15:R14 pointing to GPIO (note this clashes with ISR but ISR uses bank switching)
LDI 14,>GPIO_ADDR
LDI 15,<GPIO_ADDR

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
LDM 3,15,14			; store R1 to GPIO
LDI 5,0x01
:INCLOOP
INC 1,1				; R1 = R1 + 1
ADC 2,2,4			; increment R2 if carry
ADC 3,3,4			; increment R3 if carry
DEC 5,5
JNZ INCLOOP
STM 3,15,14			; store R1 to GPIO
RET

; Recall to move this if you enable FASTMEM (to 0x0F80)
.ORG 0x0F00			; IRQ vector (word 0x0F00 == address 0x1E00)
:ISR
LDM 0,15,14			; read from UART
STM 0,15,14			; echo it back	
RETI

