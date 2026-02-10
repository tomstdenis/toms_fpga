; Test sequence #1 for useq_tb.v (i_port should be assigned 8'hAB, [*] denotes 2 cycle
.ORG 00
; Cycle 1, all regs should be zero'ed
INC						; A = 01, R[] = {0}, PC = 00, LR = 00, ILR = 00
ST 0					; R[0] = 01,  PC = 01
INC						; A = 02, PC = 02
ST 7					; R[7] = 02, PC = 03
LD 0					; A = 01, PC = 04
SETB 0,0				; A = 00, PC = 05
SETB 7,1				; A = 80, PC = 06
ADD 7					; A = 82, PC = 07
SUB 0					; A = 81, PC = 08
EOR 7					; A = 83, PC = 09
AND 0					; A = 01, PC = 0A
OR 7					; A = 03, PC = 0B
JMP 0					; PC = 0C
DEC						; A = 02, PC = 0D
ASL						; A = 04, PC = 0E
LSR						; A = 02, PC = 0F
ASR						; A = 01, PC = 10
SWAP					; A = 10, PC = 11
ROL						; A = 20, PC = 12
ROR						; A = 10, PC = 13
SWAPR0					; A = 01, R[0] = 10, PC = 14
SWAPR1					; A = 00, R[1] = 01, PC = 15
NOT						; A = FF, PC = 16
CLR						; A = 00, PC = 17
LDA						; A = A0, PC = 18, R14 = 01
SIGT					; PC = 19, should skip next opcode since A (A0) > R[0] (10) [*]
CLR						; should not run
SIEQ					; PC = 1B (A != R[0]) [*]
SILT					; PC = 1C (A > R[0]) [*]
LDIB F					; A = AF, PC = 1D
LDIT 1					; A = 1F, PC = 1E
OUT						; o_port = 1F, PC = 1F
TGLBIT					; o_port = 1D, PC = 20
OUTBIT					; o_port = 1D, PC = 21 
IN						; A = AB, PC = 22
INBIT					; A = 01, PC = 23
NEG						; A = FF, PC = 24
SBIT 0,1				; PC = 25 [*]
CLR						; should not run
SBIT 7,0				; PC = 27 [*]
CLR						; A = 00, PC = 28
LDIB >CALLTGT			; A = 00, PC = 29
LDIT <CALLTGT			; A = 60, PC = 2A
CALL					; PC = 2B, LR = 2C [test goes to .ORG 60] [*]
JMPA					; PC = 2C ; test ends here [*]

.ORG 60
:CALLTGT
RET						; PC = 60, [test goes to .ORG 37] [*]
