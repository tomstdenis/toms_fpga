; -------------------------------------------------------------
; Toy ISA Program: Block Memory Fill
; Purpose: Fills a block of memory with a pattern. 
; Tests: LD, ST, ADD, SUB, JZ, JMP, LDi, and indirect addressing
; -------------------------------------------------------------
.ORG 32
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
    LDi  R0, 1             ; R0 <= 1
fill_loop:
    ; Step 3: Write the pattern (using the current count in R1 as the data)
    ST   R1, R3        

    ; Step 4: Advance pointer (R3++) and decrement counter (R1--)
    ADD  R3, R0        ; R3 <= R3 + 1 (Move to next memory location)
    SUB  R1, R0        ; R1 <= R1 - 1 (Decrement loop counter, updates ZF)

    JZ done
    JMP fill_loop     ; Loop back

done:
    HALT               ; Stop execution. External flag raised.

