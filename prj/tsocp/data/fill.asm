; -------------------------------------------------------------
; Toy ISA Program: Block Memory Fill
; Purpose: Fills a block of memory with a pattern. 
; Tests: LD, ST, ADD, SUB, JZ, JMP, LDi, and indirect addressing
; -------------------------------------------------------------
.ORG 0
dest_ptr:
    80                 ; Target memory block starts at address 80
block_count:
    33                 ; Fill 0x33 bytes of memory

.ORG 32

setup:
    ; Step 1: Initialize our target pointer
    LDi  dest_ptr      ; R0 <= address of dest_ptr (0)
    LD   R3, R0        ; R3 <= mem[R0] (R3 now holds the value 80, our destination)

    ; Step 2: Initialize our loop counter
    LDi  block_count   ; R0 <= address of block_count (1)
    LD   R1, R0        ; R1 <= mem[R0] (R1 now holds the loop count: 10)

fill_loop:
    ; Step 3: Check if count (R1) has hit 0
    LDi  0             ; R0 <= 0
    ADD  R0, R1        ; Force flags to update based on R1 (ZF = !R1)
    JZ   done          ; If R1 == 0, we are finished!

    ; Step 4: Write the pattern (using the current count in R1 as the data)
    ST   R1, R3        

    ; Step 5: Advance pointer (R3++) and decrement counter (R1--)
    LDi  1             ; R0 <= 1
    ADD  R3, R0        ; R3 <= R3 + 1 (Move to next memory location)
    SUB  R1, R0        ; R1 <= R1 - 1 (Decrement loop counter, updates ZF)

    JMP  fill_loop     ; Loop back

done:
    HALT               ; Stop execution. External flag raised.

