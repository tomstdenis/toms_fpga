Tom's tiny MicroSequencer.

This is a module that implements a tiny 8-bit processor that operates out of an upto
4096 byte ROM space.  The core features an 8-bit accumulator, and 16 'R' registers.  The
instruction set is typical of late 70s early 80s accumulator based but with plenty of
bit twiddling related instructions.  Also being lighlty pipelined most instructions
are single cycle too.

The core features an 8-bit input port "i_port" and an 8-bit output port "o_port" that you 
can connect to other modules or pins as you see fit.  The CPUs can write and read from them.  The
ports don't have to be overlapping (e.g. you can connect upto 16 distinct nets outside the module
8 of which are input, 8 are output).

The core features a variable sized FIFO that the processor can read from/write to aswell
as the parent module can force FIFO actions though a 2nd I/O pair into the core.  This gives 
flexibility about how you get data in and out of the cores.  The parent module is also given
fifo_full and fifo_empty signals to see the status of the fifo.  Whenever a read or write
command is issued the CPU is halted while the operation happens.  Reads from an empty FIFO
return 0, writes to a full FIFO are discarded.

The core also features an IRQ system where you can mask the i_port to tell it which bits you want
to trigger on a leading positive edge with the SEI instruction.  The imm operand to SEI tells the
core which bits of i_port you care about.  When a posedge is detected on any of them the IRQ is
triggered.  Once in an ISR interrupts are disabled until an RTI opcode is executed.  The IRQ system
also saves A, R0, and R1 to a temporary buffer allowing the ISR to overwrite them.

ISRs default to address 0xF0 (so that it's at the top of a 256 byte ROM which is the smallest practical size)
but can be moved with the SAI instruction.  ISRs must be on a 16-byte aligned address.

Fun ideas:
	- Tie a timer to a one of the pins and make enabled in the int_mask to have a nice timer in your code.
	
	- If your parent module uses inout pins you can treat o_port like how say an 8574 works.  Writing a 1 bit to o_port makes that pin
	a high high impedence with a pullup meaning if an external source pulls it low it'll read as low on i_port.  In this way you can map the 16
	i_port and o_port pins to a single set of 8-pins.  This can be used to do things like one-wire protocols, I2C, etc.  At 50MHz you have
	about 500 cycles per bit at 100KHz say I2C, plenty of time, even at 400KHz that's 125 cycles.  Given most opcodes run in 1 cycle you're golden.
	In I2C mode you'd set R0 to the SDA pin and R1 to the SCL pin.  This allows you to use INBIT/OUTBIT with SDA and TGLBIT with SCL.
	An OUTBIT of 1 would turn the SDA pin into a pullup input.  An OUTBIT of 0 would turn SDA into an output low.  (Remember your external
	pullups!)

	- You could also have multiple cores with one as a bus master which pushes into it's FIFO, the parent module then reads those bytes and pushes them
	into the slave module FIFOs.  If you have a WAITF on the slaves they can wait for a "frame", make the first byte contain a target ID and you 
	can send a message to a specific slave.  You can setup the parent module to then read from any slave FIFO and send it to the master's FIFO, etc.  The
	downside is the FIFO can't be used internally for other logic but the upside is you get the full i_port/o_port per core for other connectivity.

	- Variant of the above is you could make one of the target IDs the parent module itself so you could send commands to reconfigure the other slaves for
	instance if they use SRAM or BRAMs, you could dynamically upload code to the other cores :-) (just hold the target core in reset until you program
	the code memory, then release reset)

	- A variant of the other idea is you could bitbang data via a SPI or UART like protocol.  E.g. fan the TX pin of the master to the slaves RX pins, and
	OR the slave TX pins to the masters RX pin
	
	- Delays, the following code
	
	; load A
	:WAITTOP
	WAITA
	DEC
	JNZ WAITTOP
	
	will delay if you load A with n for C = 1/2 * (n^2 + 9*n) cycles.  This allows you to make somewhat fine controlled delays from 5 to 33,660 cycles with a 3 byte loop.	
	for instance at 95MHz you need an n of 36, 53, 95, or 136 for 115200, 57600, 19200, or 9600 baud to time the bits correctly (well with a small error).  To work
	out what you need for n for a given cycle count of C just use the formula n = (sqrt(8C + 81) - 9) / 2
	
The module is defined as follows:
	
module useq
#(parameter
	FIFO_DEPTH=16,
	ISR_VECT=12'hF0,
	ENABLE_IRQ=1,
	ENABLE_HOST_FIFO_CTRL=1
)(
	input clk,
	input rst_n,
	
	input [15:0] mem_data,				// memory[mem_addr..mem_addr+1]
	input [7:0] i_port,					// input port you can connect other pins to feed data into the core

	input read_fifo,					// pulse this high to read a byte from the FIFO into fifo_out in the next clock cycle
	input write_fifo,					// pulse this high to write from fifo_in into the FIFO
	output fifo_empty,					// high when the FIFO is empty
	output fifo_full,					// high when the FIFO is full
	input [7:0] fifo_in,				// The FIFO input into the core when pulsing write_fifo 
	output reg [7:0] fifo_out,			// The fifo output from the core when pulsing read_fifo
	
	output reg [11:0] mem_addr,			// The address the core needs mem_data from in the next clock cycle
	output reg [7:0] o_port,			// output port you can connect other pins to feed data out of the core.
	output reg o_port_pulse				// This pin toggles when a write to o_port is done.
);

The memory requires a dual ported memory though while no writes are supported right now from this core will likely only
write via one port anyways.  So a RW/R configuration would work.  The parent module should feed the two bytes starting at mem_addr
into mem_data.

On my Tang Nano 20K the design with a 4K BRAM can hit around 95MHz using 1072 LUT, 88 ALU, 273 registers, 751 CLS, 2 DPB, and 1 MULT9x9.

The included assembler useq_as.c is very barebones but complete enough to be useful.  All opcodes must be
uppercase.  Since the programs are small the assembler just links things in place allowing forward/backward
references.  The assembler produces a HEX file that is compatible with GoWin IP core generators and can be
read by verilogs readmemh if you drop the first three lines.  The assembler supports a variety of directives.

The ".ORG" directive tells the assembler where to start assembling new code.  For instance

	.ORG 40
	
Tells the assembler to start working at 0x40.

The ".EQU" directive allows you to define constants that you can use in several commands that take
4-bit 'r' parameters and all imm EXEC2 commands.  For instance,

	.EQU INT_MASK 7F
	
Defines a symbol INT_MASK that resolves to 7F in assembling the code.

The ".ALIGN" directive tells the assembler to align to the next multiple of the value you give it.  For instance,

	.ALIGN 10
	
Advances the origin to the next multiple of 16 bytes.  Handy for the JSR command in EXEC1 mode since it can only
target multiples of 16 bytes.

The ".DB" directive allows you to insert data directly in the output.  For instance,

	.DB 55
	
Puts the byte 0x55 in memory at that current origin.

Instruction Map:

// all 1 cycle
0r: LD r, 			A = R[r], PC += 1
1r: ST r, 			R[r] = A, PC += 1		; for LD and ST if r==15 then it interacts with the FIFO not R[15] itself
2sb: SETB s, b, 	A[s] = b, PC += 1   	; Set bit s of A to b
3r: ADD r, 			A = A + R[r], PC += 1 	; for these ALU opcodes R[15] reads as the fifo count (how many valid bytes)
4r: SUB r, 			A = A - R[r], PC += 1
5r: EOR r, 			A = A ^ R[r], PC += 1
6r: AND r, 			A = A & R[r], PC += 1
7r: OR r, 			A = A | R[r], PC += 1


// all 1 cycle except for LDM/STM
80: LDI imm			A = ROM[PC+1], PC = PC + 2
81: ADDI imm		A = A + ROM[PC+1], PC = PC + 2
82: SUBI imm		A = A - ROM[PC+1], PC = PC + 2
83: EORI imm		A = A ^ ROM[PC+1], PC = PC + 2
84: ANDI imm		A = A & ROM[PC+1], PC = PC + 2
85: ORI imm			A = A | ROM[PC+1], PC = PC + 2
86: LDR0 imm		R[0] = imm, PC += 2
87: LDR1 imm		R[1] = imm, PC += 2;
88: LDR11 imm		R[11] = imm, PC += 2;
89: LDR12 imm		R[12] = imm, PC += 2;
8A: LDR13 imm		R[13] = imm, PC += 2;
8B: LDR14 imm		R[14] = imm, PC += 2;
8C: MUL				{R[0], A} = A * R[0], PC += 1
8D: LDM 			A <= ROM[{R[14], R[13]}, {R[14], R[13]} <= {R[14], R[13]} + 1'b1;   (ram and rom are the same address space
8E: STM				RAM{R[12], R[11]} <= A, {R[12], R[11]} <= {R[12], R[11]} + 1'b1;    (not yet implemented)
8F: XXX 

// all 1 cycle
90: INC, 			A = A + 1, PC += 1
91: DEC, 			A = A - 1, PC += 1
92: ASL, 			A = A << 1, PC += 1
93: LSR, 			A = A >> 1, PC += 1
94: ASR, 			A = signed(A >> 1), PC += 1
95: SWAP, 			A = {A[3:0], A{7:4}}, PC += 1 // SWAP
96: ROL, 			A = {A[6:0], A[7]}, PC += 1 // ROL
97: ROR, 			A = {A[0], A[7:1]}, PC += 1 // ROR
98: SWAPR0, 		A and R[0] swap spaces, PC += 1
99: SWAPR1, 		A and R[1] swap spaces, PC += 1
9A: NOT, 			A = ~A, PC += 1
9B: CLR, 			A = 0, PC += 1
9C: SIGT, 			A = (A > R[0]) ? 1 : 0, PC += 1
9D: SIEQ, 			A = (A == R[0]) ? 1 : 0, PC += 1
9E: SILT, 			A = (A < R[0]) ? 1 : 0, PC += 1
9F: XXX

// relocations are 2 cycles
Ax: JMP IMM12		PC = {instruct[3:0], imm}
Bx: CALL IMM12		LR = PC + 2, PC = {instruct[3:0], imm}
Cx: JZ IMM12		if (A == 0) PC = {instruct[3:0], imm}
Dx: JNZ IMM12		if (A != 0) PC = {instruct[3:0], imm}

// 1 cycle, except E7-EF which are 2+ cycles
E0: OUT, 			o_port = A, PC += 1
E1: OUTBIT, 		o_port[R0[2:0]] = A[0], PC += 1  // fast set-1
E2: TGLBIT, 		o_port[R1[2:0]] ^= 1, PC += 1    // fast toggle-1			<--- things clock pin related use R1 to address the pin
E3: IN, 			A = i_port, PC += 1
E4: INBIT, 		 	A = i_port[R0[2:0]] ? 1 : 0 , PC += 1
E5: NEG				A = -A, PC += 1
E6: NOP
E7: SEI imm			int_mask = imm, PC += 2
E8: SAI imm			int_vect = imm << 4; PC += 2;
E9: HLT				PC = PC
EA: RET, 			PC = LR
EB: RTI, 			PC = ILR, re-enable interrupts and return
EC: WAIT0,			PC = PC + (i_port[R1[2:0]]) ? 0 : 1							<---- since WAIT's are likely clock related we use R1 to address the pin here
ED: WAIT1,			PC = PC + (i_port[R1[2:0]]) ? 1 : 0
EE: WAITF: 			PC = PC + (R[15] >= A) ? 1 : 0, // wait for FIFO to have at least A bytes in it, you need an ISR that stores in the fifo for this to advance
EF: WAITA, 			T = A, A = A - 1, PC += (A == 0) ? 1 : 0, A = T when it stops waiting

// 1 cycle
Fsb: SBIT s, b		Skip next instruction if bit s of A is b, PC = PC + 1 + (A[s] == b) ? 1 : 0
