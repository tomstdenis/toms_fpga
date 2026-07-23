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
        - Rd: [1:0] (also used to pick sub groups for various groups like LDi, JMP, RET, and HALT)
        - imm is the next byte

    - Instructions (upper 4 bits of 8-bit opcode, some 1 or 0 OP opcodes use bits [1:0] as a sub-opcode)
		- 0: ADD Rs, Rd    : Rs <= Rs + Rd   (ZF=!Rs)
		- 1: SUB Rs, Rd    : Rs <= Rs - Rd   (ZF=!Rs)
		- 2: XOR Rs, Rd    ; Rs <= Rs ^ Rd   (ZF=!Rs)
		- 3:  OR Rs, Rd    ; Rs <= Rs | Rd   (ZF=!Rs)
		- 4: AND Rs, Rd    ; Rs <= Rs & Rd   (ZF=!Rs)
		- 5:
			0: LDi Rs, imm   : Rs <= mem[PC+1] (ZF=!Rs)
			1: ADDi Rs, imm   : Rs <= Rs + mem[PC+1] (ZF=!Rs)  (note SUBi is just 256 - imm)
			2: XORi Rs, imm   : Rs <= Rs ^ mem[PC+1] (ZF=!Rs)
			3: ANDi Rs, imm   : Rs <= Rs & mem[PC+1] (ZF=!Rs)
		- 6: LD Rs, Rd     : Rs <= mem[Rd]   (ZF=!Rs)
		- 7: ST Rs, Rd     : mem[Rd] <= Rs
		- 8: 
			0: JMP imm     : PC <= mem[PC+1]
			1: JZ imm      : if ZF then PC <= mem[PC+1] else PC <= PC + 2
			2: JNZ imm     : if !ZF then PC <= mem[PC+1] else PC <= PC + 2
			3: JALR imm    ; R3 = PC + 2, PC = mem[PC+1]
		- 9:
			0: INC  Rs     ; INC Rs, ZF = !Rs
			1: DEC  Rs     ; DEC Rs, ZF = !Rs
			2: SHR  Rs     ; SHR Rs, 1, ZF = !Rs
			3: SZF  Rs     ; Rs <= {7'b0, ZF}
		-10: MOV Rs,Rd     ; Rs <= Rd (ZF=!Rs)
		-11: (Rd = subop) 
			0: RET         ; PC = R3
			1: NOT Rs      ; Rs <= ~Rs                 (ZF=!Rs)
			2: NEG Rs      ; Rs <= -Rs                 (ZF=!Rs)
			3: SWAP Rs     ; Rs <= {Rs[3:0], Rs[7:4]}  (ZF=!Rs)
		-12: SILT Rs, Rd   ; ZF = Rs < Rd ? 1 : 0
		-13: SIEQ Rs, Rd   ; ZF = Rs == Rd ? 1 : 0
		-14: SIGT Rs, Rd   ; ZF = Rs > Rd ? 1 : 0
		-15: (Rd = subop)
			0: HALT        : Halt cpu and raise external flag
			1: MSB Rs      ; ZF = Rs[7]
			2: LSB Rs      ; ZF = Rs[0]
			3: XXXX        ; free slot for a 1OP or 0OP opcode
