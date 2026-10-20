.org 0
MOV FWDSYM > A
MOV TOPVAL > B
JSR FWDLABEL
FWDSYM = $14
FWDLABEL:

TOM = $1000
.org TOM
    MOV B,A > A
.org 256
    MOV ($1234) > (65535)
    (C) XOR %10001 , A > S1
    MOV $2000 > PC
.org %10000000
    (!Z) MOV C > D
BAR:
    (Z AND C) MOV A > (BAR)
    CLRC
    JSR TOM ; jump to TOM
    BCHK ($9000),15
    LDSP A
    STSP (12)
.org $2000
    .word $1122
    .word TOM
    INC B > B
    SHR C > D
