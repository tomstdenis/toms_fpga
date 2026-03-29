XOR 0, 0, 0				; clear R0
LDI 1, 0x1				; R1 = 1, count up by 1 initially
LDI 2, 0x1				; R2 = 1, how much to increase how much to count by
:LOOP
ADD 0, 0, 1				; R0 = R0 + R1
JNZ LOOP
ADD 1, 1, 2				; increment what we count by by 1
JMP LOOP

