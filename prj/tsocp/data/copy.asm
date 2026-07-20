.ORG 0
src_ptr:
    80
dst_ptr:
    A0                 ; Target memory block starts at address 80
block_count:
    20                 ; copy 0x20 bytes

.ORG 32

setup:
    LDi src_ptr
    LD R3,R0
    LDi dst_ptr
    LD R2,R0
    LDi block_count
    LD R1,R0

loop:
    LD R0,R3
    ST R0,R2
    LDi 1           ; our inc counter
    ADD R2,R0
    ADD R3,R0
    SUB R1,R0
    JZ done
    JMP loop

done:
    HALT               ; Stop execution. External flag raised.


; data to copy
.ORG 128
    01
    02
    03
    04
    05
    06
    07
    08
    09
    0A
    0B
    0C
    0D
    0E
    0F
    10
    11
    12
    13
    14
    15
    16
    17
    18
    19
    1A
    1B
    1C
    1D
    1E
    1F
    20
