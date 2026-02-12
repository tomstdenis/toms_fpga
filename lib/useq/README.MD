Tom's tiny MicroSequencer.

This is a module that implements a tiny 8-bit processor that operates out of a 
256 byte ROM space.  The core features two instruction sets (EXEC1 and EXEC2) that are designed
for bit manipulations (EXEC1), and general ALU math (EXEC2).  Most instructions are
single cycle.  You can switch instruction set modes with a single cycle instruction.

The core features an 8-bit accumulator, and 16 'R' registers.  In EXEC1 mode math centers around
the A register which allows for flexbility to test, set, manipula bits and I/O bits.  In EXEC2
mode math centers around the first 4 R registers allowing more orthogonal ALU operations.

Both modes overlap in registers.  When you switch modes the registers are the same allowing you
to switch to a mode as necessary if the work requires a different centricity.

The core features an 8-bit input port "i_port" and an 8-bit output port "o_port" that you 
can connect to other modules or pins as you see fit.  The CPUs can write and read from them.

The core features a variable sized FIFO that the processors can read from/write to aswell
as the parent module can force FIFO actions though a 2nd I/O pair into the core.  This gives 
flexibility abou how you get data in and out of the cores.  The parent module is also given
fifo_full and fifo_empty signals to see the status of the fifo.  Whenever a read or write
command is issued the CPU is halted while the operation happens.  Reads from an empty FIFO
return 0, writes to a full FIFO are discarded.

The core also features an IRQ system where you can mask the i_port to tell it which bits you want
to trigger on a leading positive edge with the SEI instruction.  Whichever execution mode issues the SEI instruction
is the mode the core will switch to to execute the ISR.  This allows you to have a EXEC1 ISR work
correctly while running EXEC2 code.  Once in the ISR the core disables intterupts until a RTI
is executed.  The base address of the ISR defaults to 8'hF0 but you can relocate it with the EXEC2 SIA
instruction (this instruction does not change which mode the ISR runs in, only SEI does that).  When an IRQ happens
the core saves A, R[0], and R[1] to a temporary space which allows your ISR to destroy their values without 
saving them manually.  Any other register changed (including the FIFO) will be changed when you return from the interrupt.

The module allows parameterization.  You can disable EXEC1 or EXEC2 mode, you can disable IRQ support,
and you can disable host control of the FIFO.

It's best to think of EXEC1 mode as a PIO like block.  It has instructions good for waiting for bit conditions,
waiting counters, toggling I/O pins, reading/writing single bits of I/O pins, etc.  And, it's best to think
of EXEC2 as like an AVR sorta processor.  It has more register-register ALU opcodes, has 8-bit immediate
support for JMP/CALL/LDI/JZ/JNZ (which is more practical than what EXEC1 has), etc.  The core is designed
to make switching between the two as fast as possible (1 cycle).  So if you can save more than 2 cycles
by switching modes it's worth doing.

Both modes can access the I/O and FIFOs so you've got options if you want to go for a one mode only core.  Just keep
in mind that comes with limitations.

On my Tang Nano 20K (GW2AR-18) I get the following sizes/times (keep in mind these should be treated as estimates...)

	- All enabled: 85MHz, 1110 CLS, 1605 LUT, 129 ALU, 128 ROM16, 259 Registers
	- SLIM EXEC1+2: 80MHz, 1035 CLS, 1484 LUT, 128 ALU, 128 ROM16, 214 Registers
	- EXEC1 Only: 104Mhz, 667 CLS, 783 LUT, 84 ALU, 128 ROM16, 248 Registers
	- SLIM EXEC1 Only (no IRQ/Host FIFO): 100MHz, 649 CLS, 760 LUT, 84 ALU, 128 ROM16, 213 Registers
	- EXEC2 Only: 98MHz, 743 CLS, 1033 LUT, 37 ALU, 128 ROM16, 231 Registers
	- SLIM EXEC2 Only (no IRQ/Host FIFO): 96 Mhz, 667 CLS, 924 LUT, 46 ALU, 128 ROM16, 188 Registers

Keep in mind that at 80+ MHz that means 80+ MIPS :-).  If you filled the memory with TGLBIT you'd have a 40MHz square wave
coming out of the core.

Fun ideas:
	- Tie a timer to a one of the pins and make enabled in the int_mask to have a nice timer in your code.
	
	- Use one+ of the output pins to do a bank switch, e.g.
	
		:TGLBANK
		ST F			// Save A using FIFO
		LDIB A,PIN
		ST 1			// set R[1] to the pin you want to toggle
		TGLBIT
		LD F			// Restore A
		JMPA
		
	  Put that at the same address in both banks and then whenever you jump here you load A with the offset you want to move to in the next
	  bank.  Keep in mind this'll break ISRs unless you also put the same ISR code in each bank.
	  
	- Another way is instead of using a ROM primitive you use a 1-cycle RAM primitive (requirement is an address latched in cycle N-1 should
	be available by cycle N).  If need be you could halt the core by holding the fifo_read signal high.  You would have to OR the core's
	address with your addressing since the memory would likely be single ported.  You could use DP BSRAM if it satisfies the max 1-cycle latency
	(which most do).  Point is you could just re-write core memory as long as it's not actively accessing what you're writing.
	
	- If you need to jump between EXEC1 and EXEC2 blocks you should switch to EXEC2 before jumping to the body of the EXEC2 code so that
	you can use the more powerful JMP imm form in EXEC2.  Remember to switch back to EXEC1 before jumping to the EXEC1 body.
	
	- If your parent module uses inout pins you can treat o_port like how say an 8574 works.  Writing a 1 bit to o_port makes that pin
	a high high impedence with a pullup meaning if an external source pulls it low it'll read as low on i_port.  In this way you can map the 16
	i_port and o_port pins to a single set of 8-pins.  This can be used to do things like one-wire protocols, I2C, etc.  At 50MHz you have
	about 500 cycles per bit at 100KHz say I2C, plenty of time, even at 400KHz that's 125 cycles.  Given most opcodes run in 1 cycle you're golden.
	In I2C mode you'd set R0 to the SDA pin and R1 to the SCL pin.  This allows you to use INBIT/OUTBIT with SDA and TGLBIT with SCL.
	An OUTBIT of 1 would turn the SDA pin into a pullup input.  An OUTBIT of 0 would turn SDA into an output low.  (Remember your external
	pullups!)
	
	
module useq
#(parameter
	FIFO_DEPTH=16,
	ISR_VECT=8'hF0,
	ENABLE_EXEC1=1,
	ENABLE_EXEC2=1,
	ENABLE_IRQ=1,
	ENABLE_HOST_FIFO_CTRL=1
)(
	input clk,
	input rst_n,
	
	input [7:0] mem_data,				// ROM[mem_addr]
	input [7:0] i_port,					// input port you can connect other pins to feed data into the core

	input read_fifo,					// pulse this high to read a byte from the FIFO into fifo_out in the next clock cycle
	input write_fifo,					// pulse this high to write from fifo_in into the FIFO
	output fifo_empty,					// high when the FIFO is empty
	output fifo_full,					// high when the FIFO is full
	input [7:0] fifo_in,				// The FIFO input into the core when pulsing write_fifo 
	output reg [7:0] fifo_out,			// The fifo output from the core when pulsing read_fifo
	
	output reg [7:0] mem_addr,			// The address the core needs mem_data from in the next clock cycle
	output reg [7:0] o_port,			// output port you can connect other pins to feed data out of the core.
	output reg o_port_pulse				// This pin toggles when a write to o_port is done it's not an active high/low 
);


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

The ".MODE" directive tells the assembler to switch instruction set modes.  Mode 1 refers to EXEC1 and mode 2 refers to EXEC2.
You must use the opcode to switch before setting the mode.  For instance:

	EXEC2
	.MODE 2
	; Now we're EXEC2 mode on the 2nd cycle.

This design assumes that mem_data will have the 8 bits from ROM[mem_addr] registered in the previous cycle.

The ROM16s (configured as 8x256) is loaded at synthesis time and once it comes out of reset
it starts at address 0.  The "memory" must be able to provide mem_data at the next cycle (must be combinatorial).

The first instruction set is meant for bit manipulations and works around the accumulator A register.  Several
registers have special meanings for some instructions.  LDA for instance is used to read A = ROM[A].  To speed
up reading a ROM table it stores the index A + 1 into R14, so you can issue a 'LD E' to load it the next
address into A.  For OUTBIT and INBIT the core uses the lower 3 bits of R[0] as the bit from the port to use.
Whereas, TGLBIT uses the lower 3 bits of R[1].  This is meant so you can specify a data pin in R0 and a clock
pin in R[1].

EXEC1:
0r: LD r, 			A = R[r], PC += 1
1r: ST r, 			R[r] = A, PC += 1		; for LD and ST if r==15 then it interacts with the FIFO not R[15] itself
2sb: SETB s, b, 	A[s] = b, PC += 1   	; Set bit s of A to b
3r: ADD r, 			A = A + R[r], PC += 1 	; for these ALU opcodes R[15] reads as the fifo count (how many valid bytes)
4r: SUB r, 			A = A - R[r], PC += 1
5r: EOR r, 			A = A ^ R[r], PC += 1
6r: AND r, 			A = A & R[r], PC += 1
7r: OR r, 			A = A | R[r], PC += 1
8r: JMP r,			PC = PC + zeroext(r)
9r: JNZ r,			if A then PC = PC - zeroext(r), else PC += 1
A0: INC, 			A = A + 1, PC += 1
A1: DEC, 			A = A - 1, PC += 1
A2: ASL, 			A = A << 1, PC += 1
A3: LSR, 			A = A >> 1, PC += 1
A4: ASR, 			A = signed(A >> 1), PC += 1
A5: SWAP, 			A = {A[3:0], A{7:4}}, PC += 1 // SWAP
A6: ROL, 			A = {A[6:0], A[7]}, PC += 1 // ROL
A7: ROR, 			A = {A[0], A[7:1]}, PC += 1 // ROR
A8: SWAPR0, 		A and R[0] swap spaces, PC += 1
A9: SWAPR1, 		A and R[1] swap spaces, PC += 1
AA: NOT, 			A = ~A, PC += 1
AB: CLR, 			A = 0, PC += 1
AC: LDA, 			R14 = A + 1, A = ROM[A], PC += 1 (R14 stores a pointer to the next byte you can fetch with "LD E")
AD: SIGT, 			PC = PC + 1 + (A > R[0]) ? 1 : 0   // skip if greater
AE: SIEQ, 			PC = PC + 1 + (A == R[0]) ? 1 : 0  // skip if equal
AF: SILT, 			PC = PC + 1 + (A < R[0]) ? 1 : 0   // skip if less than
Br: LDIB r, 		A[3:0] = r, PC += 1
Cr: LDIT r, 		A[7:4] = r, PC += 1
D0: OUT, 			o_port = A, PC += 1
D1: OUTBIT, 		o_port[R0[2:0]] = A[0], PC += 1  // fast set-1
D2: TGLBIT, 		o_port[R1[2:0]] ^= 1, PC += 1    // fast toggle-1			<--- things clock pin related use R1 to address the pin
D3: IN, 			A = i_port, PC += 1
D4: INBIT, 		 	A = i_port[R0[2:0]] ? 1 : 0 , PC += 1
D5: NEG:			A = -A, PC += 1
D6: SEI, 			PC += 1, int_mask = A, if i_port & int_mask is a posedge (prev < cur) (from registered copy) then IRQ
D7: JMPA, 			PC = A
D8: CALL, 			LR = PC + 1, PC = A
D9: RET, 			PC = LR
DA: RTI, 			PC = ILR, re-enable interrupts and return
DB: WAIT0,			PC = PC + (i_port[R1[2:0]]) ? 0 : 1							<---- since WAIT's are likely clock related we use R1 to address the pin here
DC: WAIT1,			PC = PC + (i_port[R1[2:0]]) ? 1 : 0
DD: EXEC2 			Byte that follows PC is from the EXEC2 table
DE: WAITF: 			PC = PC + (R[15] >= A) ? 1 : 0, // wait for FIFO to have at least A bytes in it, you need an ISR that stores in the fifo for this to advance
DF: WAITA, 			T = A, A = A - 1, PC += (A == 0) ? 1 : 0, A = T when it stops waiting
Er: JSR r, 			PC = r << 4 // (jump to a 16 byte aligned ROM address)
Fsb: SBIT s, b		Skip next instruction bit s of A is b, PC = PC + 1 + (A[s] == b) ? 1 : 0

In EXEC2 we focus mostly on R[] to R[] operations to the opcode is 4 bits for opcode and typically 2 bits r, and s to pick from R[0..3].
In this mode you still have access to the I/O port but only on an 8-bit wide unit at a time.  So to toggle a bit you have to recall
what the o_port was set to and toggle the bit in question.  

Here 'r' and 's' are 2-bit fields.  The opcode format is 4-bit,2-bit,2-bit.  E.g. 0rs means 0000_rr_ss, where as say 62r means 0110_10_rr

EXEC2:
0rs: ADD r, s			R[r] += R[s], PC += 1
1rs: SUB r, s			R[r] -= R[s], PC += 1
2rs: EOR r, s			R[r] ^= R[s], PC += 1
3rs: AND r, s			R[r] &= R[s], PC += 1
4rs: OR r, s			R[r] |= R[s], PC += 1
5rs: MOV r, s           R[r] = R[s], PC += 1
60r: NEG r              R[r] = ~R[r], PC += 1
61r: CLR r				R[r] = 0, PC += 1
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
C3r: WAITF r			PC = PC + (QFIFO >= R[r]) ? 1 : 0, you need an ISR that stores to the FIFO otherwise this never advances (waits till at least R[r] bytes are in FIFO)
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
F03: RTI
F10: IN					A = i_port, PC += 1
F11: OUT				o_port = A, PC += 1
F12: EXEC1				Byte that follows PC is from EXEC1 table, PC = PC + 1
F13: WAITA				like mode==0 WAITA, PC += 1
F2r: SEI				int_mask = R[r], PC += 1
F3r: SIA				isr_vect = R[r], PC += 1
