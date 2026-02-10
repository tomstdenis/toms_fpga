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

reg [7:0] ROM[255:0];
wire [7:0] ROMADDR;
wire [7:0] ROMOUT = ROM[ROMADDR];

0r: LD R[r], 			A = R[r], PC += 1
1r: ST R[r], 			R[r] = A, PC += 1
2sb: SETB s, b, 		A[s] = b, PC += 1
3r: ADD R[r], 			A = A + R[r], PC += 1
4r: SUB R[r], 			A = A - R[r], PC += 1
5r: EOR R[r], 			A = A ^ R[r], PC += 1
6r: AND R[r], 			A = A & R[r], PC += 1
7r: OR R[r], 			A = A | R[r], PC += 1
8r: JMP r, 				PC = PC + zeroext(r)
9r: JNZ r, 				if A then PC = PC - zeroext(r), else PC += 1
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
AA: LDA, 				ROMADDR = A, A = ROMOUT, PC += 1
AB: SIGT, 				PC = PC + 1 + (A > R[0]) ? 1 : 0   // skip if greater
AC: SIEQ, 				PC = PC + 1 + (A == R[0]) ? 1 : 0  // skip if equal
AD: SILT, 				PC = PC + 1 + (A < R[0]) ? 1 : 0   // skip if less than
AE: NOT, 				A = ~A, PC += 1
AF: CLR, 				A = 0, PC += 1
Br: LDIB r, 			A[3:0] = r, PC += 1
Cr: LDIT r, 			A[7:4] = r, PC += 1
D0: OUT, 				o_port = A, PC += 1
D1: OUTBIT, 			o_port[R0[2:0]] = A[0], PC += 1  // fast set-1
D2: TGLBIT, 			o_port[R1[2:0]] ^= 1, PC += 1    // fast toggle-1			<--- things clock pin related use R1 to address the pin
D3: IN, 				A = i_port, PC += 1
D4: INBIT, 		 		A = i_port[R0[2:0]] ? 1 : 0 , PC += 1
D5: JMPA, 				PC = A
D6: CALL, 				R[15] = PC + 1, PC = A
D7: RET, 				PC = R[15]
D8: SEI, 				PC += 1, int_mask = A, if i_port & int_mask is a posedge (prev < cur) (from registered copy), then during fetch R[14] = PC, PC = 0xF0, further interrupts disabled until RTI
D9: RTI, 				PC = R[14], re-enable interrupts and return
DA: WAIT0, 				PC = PC + (i_port[R1[2:0]]) ? 0 : 1							<---- since WAIT's are likely clock related we use R1 to address the pin here
DB: WAIT1, 				PC = PC + (i_port[R1[2:0]]) ? 1 : 0
DC: MASK4: 				A = A[3:0], PC += 1
DD: ABS: 				A = abs(A), PC += 1
DE: NEG:				A = -A, PC += 1
DF: WAITA, 				T = A, A = A - 1, PC += (A == 0) ? 1 : 0, A = T when it stops waiting
Er: JSR r, 				PC = r << 4 // (jump to a 16 byte aligned ROM address)
Fsb: SBIT s, b			Skip next instruction bit s of A is b, PC = PC + 1 + (A[s] == b) ? 1 : 0
