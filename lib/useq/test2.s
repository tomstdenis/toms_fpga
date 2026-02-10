; Test sequence #1 for useq_tb.v (i_port should be assigned 8'hAB, [*] denotes 2 cycle
.ORG 00
NOT						; A = FF, PC = 01
SEI						; enable interrupts
INC
JSR 1
.ORG 10
JSR 1
.ORG F0
DEC
RTI
