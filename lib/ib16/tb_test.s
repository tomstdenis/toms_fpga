XOR 0, 0, 0				; clear R0
LDI 1, 0x1				; R1 = 1, count up by 1 initially
LDI 2, 0x1				; R2 = 1, how much to increase how much to count by
LDI 14, 0x01
LDI 15, 0x00
SRES 0x3				; enable post increments
:LOOP
ADD 0, 0, 1				; R0 = R0 + R1
STM 0, 14, 15			; store R0 to memory at [r14:r15 + wi]
LDM 0, 12, 13			; load R0 from memory at [r12:13 + ri]
JNZ LOOP
ADD 1, 1, 2				; increment what we count by by 1
JNZ LOOP
JMP 0

