.ORG 0
main:
    LDi R2,operands     ; R2 = pointer to operands
    JALR mult           ; call multiply routine
    LDi R1,product      ; R1 = pointer to where to store product
    ST  R0,R1           ; store product
    HALT

; mult(p) R2 => [operands], product => R0
mult:
    LDi R0,multtemp
    ST  R3,R0           ; save return address
    LD  R0, R2          ; R0 = Multiplier (A)
    INC R2
    LD  R1, R2          ; R1 = Multiplicand (B)
    LDi R3, 0           ; R3 = Accumulator (Product)

mult_loop:              ; Multiply R0 by R1 => R3
    ; Check if Multiplier (R0) is 0
    AND R0,R0           ; in reality this is easier for "is zero"
    JZ  mult_done       ; Exit loop if R0 is zero
    LSB R0              ; ZF = LSB of R0
    JZ  skip_add        ; If LSB was 0, skip adding Multiplicand
    ADD R3, R1          ; Accumulator += Multiplicand
skip_add:
    SHR R0              ; Multiplier >>= 1
    ADD R1, R1          ; Multiplicand <<= 1
    JMP mult_loop

mult_done:
    MOV R0,R3           ; R0 = R3
    LDi R3,multtemp
    LD  R3,R3           ; restore return address (LDi/LD using same reg is handy for not destroying a pointless reg)
    RET
multtemp:
.DB 0

operands:
.DB 7, 6                ; Inputs: 7, 6. Output placeholder: 0
product:
.DB 0                   ; Output placeholder: 0
