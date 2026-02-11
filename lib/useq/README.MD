Tom's tiny MicroSequencer.

Uses 128 ROM16s (5% of ShadowRAM blocks on a Tang Nano 20K) to implement 
a simple instruction set that can interact with inputs and outputs

module useq(
	input clk,
	input rst_n,
	output [7:0] mem_addr,
	input [7:0] mem_data,
	input [7:0] i_port,
	output [7:0] o_port);

This design assumes that mem_data will have the 8 bits from ROM[mem_addr] registered in the previous cycle.

The ROM16s (configured as 8x256) is loaded at synthesis time and once it comes out of reset
it starts at address 0.  The "memory" must be able to provide mem_data at the next cycle (must be combinatorial).

The ALU has 16 8-bit registers R0...R15, each instruction is 8-bits and takes 1 cycle.
(except 2r and AA which take 2 cycles)

R15 - Link register used with CALL ad RET
R14 - ISR return address used with RETI

The instruction format uses the upper 4 bits to choose an operation and the operands are in
the lower 4 bits

wire [3:0] r; // selects one of the 16 registers, the A register is separate so there are in total 17 8-bit registers.
wire [2:0] s: // selects one of the first 8 registers
wire b;       // 1 == post increment register
reg [7:0] A; // accumulator
reg [7:0] PC; // PC pointer
reg [7:0] R[15:0]; // 16 registers
reg [7:0] instr; // latched instruction for the EXECUTE stage
reg [7:0] LR;
reg [7:0] ILR;

reg [7:0] ROM[255:0];
wire [7:0] ROMADDR;
wire [7:0] ROMOUT = ROM[ROMADDR];

reg [7:0] FIFO[FIFO_DEPTH-1:0]; // FIFO that is interacted with the LD and ST opcodes when r==15

EXEC1:
0r: LD R[r], 			A = R[r], PC += 1
1r: ST R[r], 			R[r] = A, PC += 1	; for LD and ST if r==15 then it interacts with the FIFO not R[15] itself
2sb: SETB s, b, 		A[s] = b, PC += 1
3r: ADD R[r], 			A = A + R[r], PC += 1 ; for these ALU opcodes R[15] reads as the fifo count (how many valid bytes)
4r: SUB R[r], 			A = A - R[r], PC += 1
5r: EOR R[r], 			A = A ^ R[r], PC += 1
6r: AND R[r], 			A = A & R[r], PC += 1
7r: OR R[r], 			A = A | R[r], PC += 1
8r: *JMP r,				PC = PC + zeroext(r)
9r: *JNZ r,				if A then PC = PC - zeroext(r), else PC += 1
A0: INC, 				A = A + 1, PC += 1
A1: DEC, 				A = A - 1, PC += 1
A2: ASL, 				A = A << 1, PC += 1
A3: LSR, 				A = A >> 1, PC += 1
A4: ASR, 				A = signed(A >> 1), PC += 1
A5: SWAP, 				A = {A[3:0], A{7:4}}, PC += 1 // SWAP
A6: ROL, 				A = {A[6:0], A[7]}, PC += 1 // ROL
A7: ROR, 				A = {A[0], A[7:1]}, PC += 1 // ROR
A8: SWAPR0, 			A and R[0] swap spaces, PC += 1
A9: SWAPR1, 			A and R[1] swap spaces, PC += 1
AA: NOT, 				A = ~A, PC += 1
AB: CLR, 				A = 0, PC += 1
AC: *LDA, 				R14 = A + 1, A = ROM[A], PC += 1 (R14 stores a pointer to the next byte you can fetch with "LD E")
AD: *SIGT, 				PC = PC + 1 + (A > R[0]) ? 1 : 0   // skip if greater
AE: *SIEQ, 				PC = PC + 1 + (A == R[0]) ? 1 : 0  // skip if equal
AF: *SILT, 				PC = PC + 1 + (A < R[0]) ? 1 : 0   // skip if less than
Br: LDIB r, 			A[3:0] = r, PC += 1
Cr: LDIT r, 			A[7:4] = r, PC += 1
D0: OUT, 				o_port = A, PC += 1
D1: OUTBIT, 			o_port[R0[2:0]] = A[0], PC += 1  // fast set-1
D2: TGLBIT, 			o_port[R1[2:0]] ^= 1, PC += 1    // fast toggle-1			<--- things clock pin related use R1 to address the pin
D3: IN, 				A = i_port, PC += 1
D4: INBIT, 		 		A = i_port[R0[2:0]] ? 1 : 0 , PC += 1
D5: NEG:				A = -A, PC += 1
D6: SEI, 				PC += 1, int_mask = A, if i_port & int_mask is a posedge (prev < cur) (from registered copy) then IRQ
D7: *JMPA, 				PC = A
D8: *CALL, 				LR = PC + 1, PC = A
D9: *RET, 				PC = LR
DA: *RTI, 				PC = ILR, re-enable interrupts and return
DB: *WAIT0,				PC = PC + (i_port[R1[2:0]]) ? 0 : 1							<---- since WAIT's are likely clock related we use R1 to address the pin here
DC: *WAIT1,				PC = PC + (i_port[R1[2:0]]) ? 1 : 0
DD: *EXEC2 				Byte that follows PC is from the EXEC2 table
DE: *WAITF: 			PC = PC + (R[15] >= A) ? 1 : 0, // wait for FIFO to have at least A bytes in it, you need an ISR that stores in the fifo for this to advance
DF: *WAITA, 			T = A, A = A - 1, PC += (A == 0) ? 1 : 0, A = T when it stops waiting
Er: *JSR r, 			PC = r << 4 // (jump to a 16 byte aligned ROM address)
Fsb: *SBIT s, b			Skip next instruction bit s of A is b, PC = PC + 1 + (A[s] == b) ? 1 : 0


In EXEC2 we focus mostly on R[] to R[] operations to the opcode is 4 bits for opcode and typically 2 bits r, and s to pick from R[0..3].

TODO: when you hit an IRQ save which mode you are in and restore it with RTI
TODO: add a .MODE directive to tell assembler which table to use...

// NOT FINAL!!! SUPER SERIOUS!!! hehehehe
EXEC2:
0rs: ADD r, s			R[r] += R[s], PC += 1
1rs: SUB r, s			R[r] -= R[s], PC += 1
2rs: EOR r, s			R[r] ^= R[s], PC += 1
3rs: AND r, s			R[r] &= R[s], PC += 1
4rs: OR r, s			R[r] |= R[s], PC += 1
5rs: MOV r, s           R[r] = R[s], PC += 1
60r: NEG r              R[r] = ~R[r], PC += 1 (encoding is 2'b00)
61r: CLR r				R[r] = 0, PC += 1 (2'b01, etc...)
62r: LDI r, imm			R[r] = ROM[PC+1], PC += 2 (note this is a 2 cycle opcode)
63r: XCH r				A <=> R[r], PC += 1
70r: LDIND1 r			A = R[4 + r], PC += 1
71r: LDIND2 r			A = R[8 + r], PC += 1
72r: STIND1 r			R[4 + r] = A, PC += 1
73r: STIND2 r			R[8 + r] = A, PC += 1
8rs: SIGT r, s			PC = PC + 1 + (R[r] > R[s]) ? 1 : 0		// can only skip over 1 byte opcodes...
9rs: SIEQ r, s			PC = PC + 1 + (R[r] == R[s]) ? 1 : 0
Ars: SILT r, s			PC = PC + 1 + (R[r] < R[s]) ? 1 : 0
B0r: ASR r				R[r] >>= 1, PC += 1, signed
B1r: LSR r				R[r] >>= 1, PC += 1;
B2r: ADDA r				R[r] += A, PC += 1;
B3r: SUBA r				R[r] -= A, PC += 1;
C0r: RFIFO r			R[r] == read_from fifo (0 if empty), PC += 1
C1r: WFIFO r			write R[r] to fifo (or nothing if full), PC += 1
C2r: QFIFO r			Store the fifo_count in R[r], PC += 1
C3r: WAITF r			PC = PC + (QFIFO >= R[r]) ? 1 : 0, you need an ISR that stores to the FIFO otherwise this never advances (waits till R[r] bytes are in FIFO)
D0r: ANDA r				R[r] &= A, PC += 1
D1r: ORA r				R[r] |= A, PC += 1
D2r: EORA r				R[r] ^= A, PC += 1
D3r: LDA r				R[r] = A, PC += 1
E0r: JNZ r, imm			PC = R[r] == 0 ? PC + 2 : ROM[PC + 1], 2 cycle
E1r: JZ r, imm          PC = R[r] != 0 ? PC + 2 : ROM[PC + 1], 2 cycle, both of these can use the same stage since it's just doing PC <= mem_data, mem_addr <= mem_data, state <= FETCH
E2r: DEC r				R[r] -= 1, PC += 1
E3r: INC r				R[r] += 1, PC += 1
F00: JMP imm			PC = ROM[PC+1], 2 cycle, same as JNZ/JZ stage 
F01: CALL imm			LR = PC + 2, PC = ROM[PC+1], 2 cycle, same as JNZ/JZ/JMP stage
F02: RET				PC = LR
F03: ** empty (cannot take operands)
F1x: ** 4 empty (can take an 'r' param, or do 4 more no operand opcodes)
F2x: ** 4 empty (can take an 'r' param, or do 4 more no operand opcodes)
F30: IN					A = i_port, PC += 1
F31: OUT				o_port = A, PC += 1
F32: EXEC1				Byte that follows PC is from EXEC1 table, PC = PC + 1
F33: WAITA				like mode==0 WAITA, PC += 1

opcode fmt:
OP r, s
OP r, imm [2 bytes]
OP r
OP imm [2 bytes]
OP
