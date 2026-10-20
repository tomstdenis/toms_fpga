TOM = $1000
.org TOM
MOV B,A > A
.org 256
MOV ($1234) > 65535
.org %10000000
(!Z) MOV C > D
BAR:
(Z AND C) MOV A > (BAR)
