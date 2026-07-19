Toy ISA:

Regs:
    - 8-bit PC
    - four 8-bit r0, r1, r2, r3
    - Zero flag

Mem:
    - 256 byte unified code/data

Reset:
    - PC = 32
    - r0 = r1 = r2 = r3 = zeroflag = 0

Opcodes:
    - 8 bits long
        - Ins: [7:5] 
        - Rs: [3:2]
        - Rd: [1:0]
        - simm5: {[4], [4], [4], [4:0]}
        - uimm5: {3'b0, [4:0]}
    - 0: ADD Rs, Rd    : Rs <= Rs + Rd (ZF=!Rs)
    - 1: SUB Rs, Rd    : Rs <= Rs - Rd (ZF=!Rs)
    - 2: LDi uimm5     : R0 <= uimm5   (ZF=!R0)
    - 3: LD Rs, Rd     : Rs <= mem[Rd] (ZF=!Rs)
    - 4: ST Rs, Rd     : mem[Rd] <= Rs
    - 5: JMP simm5     : PC <= PC + simm5
    - 6: JZ simm5      : if ZF then PC <= PC + simm5
    - 7: HALT          : Halt cpu and raise external flag