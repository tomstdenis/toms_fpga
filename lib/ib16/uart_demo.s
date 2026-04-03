.EQU UART_ADDR 0xFFFF
.EQU GPIO_ADDR 0xFFFB
.EQU TIMER_ADDR 0xFFFA

; Setup ISR context
LDI 14,>UART_ADDR
LDI 15,<UART_ADDR

; load R12:R13 pointing to GPIO
LDI 12,>GPIO_ADDR
LDI 13,<GPIO_ADDR

; R11:R11 pointing to the timer
LDI 10,>TIMER_ADDR
LDI 11,<TIMER_ADDR

; R3:R2:R1 = 0
LDI 1,0x00
LDI 2,0x00
LDI 3,0x00

; R4 = 0
LDI 4,0x00

:LOOP
LCALL PRINT
JMP LOOP

.ALIGN 10
:PRINT
ROR 1, 1
ROL 1, 1
INC 1,1				; R1 = R1 + 1
ADC 2,2,4			; addc r2,0
ADC 3,3,4			; addc r3,0
LDM 5,11,10			; read timer
SHR 5,5				; timer >> 5 (@48Mhz each tick is 1.3653ms)
SHR 5,5
SHR 5,5
SHR 5,5
SHR 5,5
STM 5,13,12			; write it to GPIO
RET

.ORG 0x1E00			; IRQ vector
:ISR
STM 0,15,15			; push r0
LDM 0,15,14			; read from UART
STM 0,15,14			; echo it back
LDM 0,15,15			; pop r0
RETI

