; -------------------------------------------------------------
; Toy ISA Program: Block Memory Fill
; Purpose: Fills a block of memory with a pattern. 
; Tests: LD, ST, ADD, SUB, JZ, JMP, LDi, and indirect addressing
; -------------------------------------------------------------
.ORG 0
dest_ptr:
    .DB 0x80                 ; Target memory block starts at address 80
block_count:
    .DB 0x33                 ; Fill 0x33 bytes of memory

.ORG 0

setup:
    ; Step 1: Initialize our target pointer
    LDi  R3, dest_ptr  ; R3 <= dest_ptr

    ; Step 2: Initialize our loop counter
    LDi  R1, block_count   ; R1 <= block_count
fill_loop:
    ; Step 3: Write the pattern (using the current count in R1 as the data)
    ST   R1, R3        

    ; Step 4: Advance pointer (R3++) and decrement counter (R1--)
    ADDI R3,1
    DEC  R1
    JNZ fill_loop     ; Loop back

done:
    HALT               ; Stop execution. External flag raised.

