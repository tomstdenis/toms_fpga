Tom's tiny MicroSequencer.

Uses 128 ROM16s (5% of ShadowRAM blocks on a Tang Nano 20K) to implement 
a simple instruction set that can interact with inputs and outputs

module useq(
	input clk;
	input rst_n;
	output [7:0] mem_addr,
	input [7:0] mem_data,
	input [7:0] i_port,
	output [7:0] o_port);

This design assumes that mem_data will have the 8 bits from ROM[mem_addr] registered in the previous cycle.

The ROM16s (configured as 8x256) is loaded at synthesis time and once it comes out of reset
it starts at address 0.  Since the design is 2-cycles per instruction a RAM16 should also suffice
if you tie the wre pin to zero.

The ALU has 16 8-bit registers R0...R15, each instruction is 8-bits and takes 2 cycles.
(except 2r and AA which take 3 cycles)

The instruction format uses the upper 4 bits to choose an operation and the operands are in
the lower 4 bits

wire [3:0] r; // selects one of the 16 registers, the A register is separate so there are in total 17 8-bit registers.
wire [2:0] s: // selects one of the first 8 registers
wire b;       // 1 == post increment register
reg [7:0] A; // accumulator
reg [7:0] PC; // PC pointer
reg [7:0] R[15:0]; // 16 registers
reg [7:0] instr; // latched instruction for the EXECUTE stage

0r: A = R[r], PC += 1
1r: R[r] = A, PC += 1
2r: A = ROM[R[r]], PC += 1
3r: A = A + R[r], PC += 1
4r: A = A - R[r], PC += 1
5r: A = A ^ R[r], PC += 1
6r: A = A & R[r], PC += 1
7r: A = A | R[r], PC += 1
8r: PC = PC + zeroext(r)
9r: if !A then PC = PC - zeroext(r), else PC += 1
A0: A = A + 1, PC += 1
A1: A = A - 1, PC += 1
A2: A = A << 1, PC += 1
A3: A = A >> 1, PC += 1
A4: A = signed(A >> 1), PC += 1
A5: A = {A[3:0], A{7:4}}, PC += 1 // SWAP
A6: A = {A[6:0], A[7]}, PC += 1 // ROL
A7: A = {A[0], A[7:1]}, PC += 1 // ROR
A8: A and R[0] swap spaces, PC += 1
A9: A and R[1] swap spaces, PC += 1
AA: A = ROM[A], PC += 1
AB: PC = PC + 1 + (A > R[0]) ? 1 : 0   // skip if greater
AC: PC = PC + 1 + (A == R[0]) ? 1 : 0  // skip if equal
AD: PC = PC + 1 + (A < R[0]) ? 1 : 0   // skip if lessthan
AE: A = ~A, PC += 1
AF: A = 0, PC += 1
Br: A[3:0] = r, PC += 1
Cr: A[7:4] = r, PC += 1
D0: o_port = A, PC += 1
D1: o_port[A[2:0]] = A[3], PC += 1
D2: A = i_port, PC += 1
D3: PC = A
D4: R[15] = PC + 1, PC = A
D5: PC = R[15]
D6: SEI, PC += 1, if i_port[7] changed (from registered copy), then during fetch R[14] = PC, PC = 0xF0
D7: CLI, PC += 1, disable interrupt
D8: RTI, PC = R[14]
D9: WAIT0, PC = PC + (i_port[A[2:0]]) ? 0 : 1
DA: WAIT1, PC = PC + (i_port[A[2:0]]) ? 1 : 0
DB: BITI, A = i_port[A[2:0]] ? 1 : 0 , PC += 1
DC: MASK4: A = A[3:0], PC += 1
DD: ABS: A = abs(A), PC += 1
DE: NOP
DF: HALT, PC = PC (until reset)
Er: PC = r << 4 // (jump to a 16 byte aligned ROM address)
Fsb: Skip next instruction if A[s] == b
