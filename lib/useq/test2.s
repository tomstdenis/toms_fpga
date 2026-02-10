; Test sequence #2 for useq_tb.v (i_port should be assigned 8'h00, [*] denotes 2 cycle
.ORG 00
LDIB F					; A = 0F, PC = 01
LDIT 7					; A = 7F, PC = 02
SEI						; enable interrupts, PC = 03
INC						; A = 80, PC = 04
JSR 1					; PC = 05
.ORG 10
JSR 1					; PC = 10
.ORG F0
DEC						; PC = F0
RTI						; PC = F1
