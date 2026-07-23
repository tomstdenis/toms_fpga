.ORG 0
src_ptr:
    .DB 0x80
dst_ptr:
    .DB 0xA0                 ; Target memory block starts at address 80
block_count:
    .DB 0x20                 ; copy 0x20 bytes

.ORG 0

setup:
    LDi R3, src_ptr
    LDi R2, dst_ptr
    LDi R1, block_count

loop:
    LD R0,R3
    ST R0,R2
    INC R2
    INC R3
    DEC R1
    JNZ loop

done:
    HALT               ; Stop execution. External flag raised.


; data to copy
.ORG 128
    .DB 01
    .DB 02
    .DB 03
    .DB 04
    .DB 05
    .DB 06
    .DB 07
    .DB 08
    .DB 09
    .DB 0x0A
    .DB 0x0B
    .DB 0x0C
    .DB 0x0D
    .DB 0x0E
    .DB 0x0F
    .DB 0x10
    .DB 0x11
    .DB 0x12
    .DB 0x13
    .DB 0x14
    .DB 0x15
    .DB 0x16
    .DB 0x17
    .DB 0x18
    .DB 0x19
    .DB 0x1A
    .DB 0x1B
    .DB 0x1C
    .DB 0x1D
    .DB 0x1E
    .DB 0x1F
    .DB 0x20
