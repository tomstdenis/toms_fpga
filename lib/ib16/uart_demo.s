.EQU UART_ADDR 0xFFFF
.EQU GPIO_ADDR 0xFFFB
.EQU TIMER_ADDR 0xFFFA
.PROG_SIZE 4096

; Setup ISR context
LDI 14,>UART_ADDR
LDI 15,<UART_ADDR

; load R12:R13 pointing to GPIO
LDI 12,>GPIO_ADDR
LDI 13,<GPIO_ADDR

; R11:R11 pointing to the timer
LDI 10,>TIMER_ADDR
LDI 11,<TIMER_ADDR

; output counter
LDI 6,0x00

:LOOP
LDM 1,11,10
STM 1,13,12
JMP LOOP

.ORG 0x1E00			; IRQ vector
:ISR
STM 0,15,15			; push r0
LDM 0,15,14			; read from UART
STM 0,15,14			; echo it back
INC 6,6
STM 6,13,12			; echo it back
LDM 0,15,15			; pop r0
RETI

