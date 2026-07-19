    ; 8-bit constants or temp data can be stored in the first 32 bytes
    .ORG 0
    my_data:
        1F               ; Constant data stored in memory location 0

    ; Setup our starting vectors matching the reset logic (PC=32)
    .ORG 32
    start:
        LDi  my_data     ; Load the address of 'my_data' (symbol resolving) into R0
        ADD  R2, R0      ; R2 now points to our data address
        LD   R1, R2      ; R1 <= mem[R2] (reads 0x1F)
        
    loop:
        LDi  1           ; Load 1 into R0
        SUB  R1, R0      ; Decrement R1 loop counter
        JZ   exit        ; If counter hit 0, branch out
        JMP  loop        ; Else loop back
        
    exit:
        HALT             ; Stop execution 
