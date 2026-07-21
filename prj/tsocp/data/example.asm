; program begins at PC == 0
.ORG 0
start:
    LDi  R0, my_data ; Load the address of 'my_data' (symbol resolving) into R0
    ADD  R2, R0      ; R2 now points to our data address
    LD   R1, R2      ; R1 <= mem[R2] (reads 0x1F)
    
loop:
    LDi  R0, 1           ; Load 1 into R0
    SUB  R1, R0      ; Decrement R1 loop counter
    JZ   exit        ; If counter hit 0, branch out
    JMP  loop        ; Else loop back
    
exit:
    HALT             ; Stop execution 

; data 
.ORG 128
my_data:
.DB 0x1F               ; Constant data stored in memory location 0
