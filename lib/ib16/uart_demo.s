.EQU UART_ADDR 0xFFFF
.EQU GPIO0_ADDR 0xFFFB
.EQU GPIO1_ADDR 0xFFFA
.EQU TIMER_ADDR 0xFFF9
.PROG_SIZE DEMO_PROG_SIZE

; Setup ISR context
LDI 14,>UART_ADDR
LDI 15,<UART_ADDR

; load R12:R13 pointing to GPIO
LDI 12,>GPIO0_ADDR
LDI 13,<GPIO0_ADDR

; load R10:R11 pointing to GPIO1
LDI 10,>GPIO1_ADDR
LDI 11,<GPIO1_ADDR

; R11:R11 pointing to the timer
LDI 8,>TIMER_ADDR
LDI 9,<TIMER_ADDR

; output counters
LDI 6,0x00
LDI 7,0x00
LDI 2,0x00
LDI 0,0x00			; r0 == 0, let's keep that

:LOOP
LDM 1,9,8			; read timer at r9:r8
ADD 1,1,1			; get msb into carry
ADC 1,0,0			; set r1 == carry + r0(0) + r0
CMPEQ 1,2			; compare to stored value (we only move on if the MSB changed)
JC LOOP
AND 2,1,1			; r2 = r1
INC 7,7				; increment tick (this changes every 2^23 cycles (about every 131.072ms at 64MHz)
NOT 7,7				; invert it since the LEDs are inverted
STM 7,11,10			; output to GPIO1
NOT 7,7				; revert counter for next loop
JMP LOOP

.ORG IRQ_VECTOR		; IRQ vector
.INC uart_demo_isr.s
