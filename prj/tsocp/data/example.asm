; program begins at PC == 0
.ORG 0
start:
    LDi  R2, my_data ; Load the address of 'my_data' (symbol resolving) into R0
    LD   R1, R2      ; R1 <= mem[R2] (reads 0x1F)
    JALR loop
    JMP  exit
    
loop:
    DEC  R1          ; Decrement R1 loop counter
    JZ   done        ; If counter hit 0, branch out
    JMP  loop        ; Else loop back
done:
    RET    
    
exit:
    HALT             ; Stop execution 

; data 
.ORG 128
my_data:
.DB 0x1F               ; Constant data stored in memory location 128
.DB my_data
.DB 1, 2, 3, 4
