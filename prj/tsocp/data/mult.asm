.ORG 0
main:
    LDi R2,operands
    JALR mult
    LDi R1,product
    ST  R0,R1
    HALT

; mult(p) p => [operands]
mult:
    LDi R0,temp
    ST  R3,R0           ; save return address
    LD  R0, R2          ; R0 = Multiplier (A)
    INC R2
    LD  R1, R2          ; R1 = Multiplicand (B)
    LDi R3, 0           ; R3 = Accumulator (Product)

mult_loop:
    ; Check if Multiplier (R0) is 0
    LDi R2, 0
    SIEQ R0, R2         ; Is R0 == 0?
    ;AND R0,R0          ; in reality this is easier for "is zero"
    JZ  mult_done       ; Exit loop if R0 is zero

    ; Check if LSB of R0 is set using temporary AND logic
    ; (Since we need a copy of R0 to mask bit 0 without losing R0)
    ; In this ISA, we can test odd/even by shifting right and back,
    ; or by keeping a 1 in R2 to test bit 0:
    LDi R2, 1
    AND R2, R0          ; R2 = R0 & 1 (ZF = !R2)
    JZ  skip_add        ; If LSB was 0, skip adding Multiplicand

    ADD R3, R1          ; Accumulator += Multiplicand

skip_add:
    SHR R0              ; Multiplier >>= 1
    
    ; Shift Multiplicand left: R1 = R1 + R1
    ADD R1, R1          ; Multiplicand <<= 1
    JMP mult_loop

mult_done:
    XOR R0,R0
    ADD R0,R3           ; R0 = R3
    LDi R3,temp
    LD  R3,R3           ; restore return address (LDi/LD using same reg is handy for not destroying a pointless reg)
    RET

operands:
.DB 7, 6                ; Inputs: 7, 6. Output placeholder: 0
product:
.DB 0                   ; Output placeholder: 0
temp:
.DB 0