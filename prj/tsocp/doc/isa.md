Toy ISA:

Regs:
    - 8-bit PC
    - four 8-bit r0, r1, r2, r3
    - Zero flag

Mem:
    - 256 byte unified code/data

Reset:
    - PC = r0 = r1 = r2 = r3 = zeroflag = 0

Opcodes:
    - 8 bits long (* some opcodes are two)
        - Ins: [7:4] 
        - Rs: [3:2]
        - Rd: [1:0]
        - imm is the next byte
    - Instructions
		- 0: ADD Rs, Rd    : Rs <= Rs + Rd   (ZF=!Rs)
		- 1: SUB Rs, Rd    : Rs <= Rs - Rd   (ZF=!Rs)
		- 2: XOR Rs, Rd    ; Rs <= Rs ^ Rd   (ZF=!Rs)
		- 3:  OR Rs, Rd    ; Rs <= Rs | Rd   (ZF=!Rs)
		- 4: AND Rs, Rd    ; Rs <= Rs & Rd   (ZF=!Rs)
		- 5: LDi Rs, imm   : Rs <= mem[PC+1] (ZF=!Rs)
		- 6: LD Rs, Rd     : Rs <= mem[Rd]   (ZF=!Rs)
		- 7: ST Rs, Rd     : mem[Rd] <= Rs
		- 8: JMP imm       : PC <= mem[PC+1]
		- 9: JZ imm        : if ZF then PC <= mem[PC+1] else PC <= PC + 2
		-10: JALR imm      ; R3 = PC + 2, PC = mem[PC+1]
		-11: RET           ; PC = R3
		-12: SILT Rs, Rd   ; ZF = Rs < Rd ? 1 : 0
		-12: INC  Rs[, Rs] ; if Rs == Rd, then it is INC Rs, ZF = !Rs
		-13: SIEQ Rs, Rd   ; ZF = Rs == Rd ? 1 : 0
		-13: DEC  Rs[, Rs] ; if Rs == Rd, then it is DEC Rs, ZF = !Rs
		-14: SIGT Rs, Rd   ; ZF = Rs > Rd ? 1 : 0
		-14: SHR  Rs       ; if Rs == Rd, then it's SHR Rs, 1, ZF = !Rs
		-15: HALT          : Halt cpu and raise external flag
