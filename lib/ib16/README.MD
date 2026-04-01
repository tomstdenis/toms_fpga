The IttyBitty RISC 8-bit'er.

High level design

- 8Kbyte BRAM for code/data
- 512 byte SRAM for registers and other things
- multi cycle single issue non-pipelined
- Meant for 1K LUT4 FPGAs :-)
- Carry and Zero flags (only updated by ALU opcodes)
	- use a 9-bit "result DFF" so ALU opcodes can spill into bit 9 for carry flag

- BRAM is organized as follows
   - 0000..1FFF: General data/code
		- if using interrupts then the ISR begins at 1F00
   
- SRAM is organize as follows
   - 000..0FF  : Reserved
   - 100..1FF  : Stack

- MMIO:
   - Anywhere in the region of 2200..FFFF
   - the block outside the cpu routes an irq pin in to the cpu

- "memory"
   - Addresses 0000..1FFF map to BRAM
   - Addresses 2000..21FF map to SRAM
   - Both are single port, 8-bit wide, 1 cycle latency. e.g.
   - Use a simple bus protocol
		- Read:
			cycle 1: assert enable, addr
			cycle N: ready is asserted, deassert enable, read data_out
		- Write
			cycle 1: assert enable, wr_en, addr, data_in
			cycle N: ready is asserted, deassert enable, deassert wr_ren

- Registers
   - PC - 12 bits (counts 16-bit words so you fetch from memory[PC*2])
   - SP - 8 bits starts at 100 in SRAM (overall address 2100) and counts up
   - WI - 8 bits write index (used by STM if SREG[1] is set)
   - RI - 8 bits read index (used by LDM if SREG[0] is set) 
   - SREG - 8 bits (Carry, Zero, ...?)

- FSM design ("FSM" step can be multiple clock cycles though most are 1 cycle)

	- Meant for single-issue non-pipelined low resource
	- Use tag/state/cycle DFFs as tracker of state machine 
		- tag is used as a "return state" when doing co-routines like FSM_RAM
		- state: the current state the FSM is in
		- cycle: the current cycle (or step) of the current state.  Some states might have more than 1 step
			- this is meant to avoid having an excessive # of states...
			- e.g. FSM_FETCH would have "2" cycles one for byte 1 and another for byte 2 both with state == FSM_FETCH
	
	- (FSM_FETCH) Typical fetch FSM
		- FSM 1: if (!mask_int & irq) jump to FSM_IRQ, otherwise fetch opcode byte 1 via FSM_RAM
		- FSM 2: fetch opcode byte 2 via FSM_RAM, increment PC, zero "result DFF", jump to FSM_DECODE
	
	- (FSM_IRQ) Typical IRQ 
		- FSM 1: Store PC[7:0] via FSM_RAM, increment SP
		- FSM 2: Store PC[15:8] via FSM_RAM, increment SP, mask_int = 1, PC = 1F00, jump to FSM_FETCH
	
	- (FSM_DECODE) Typical decode FSM
		- If 2OP/3OP/LDM/STM
			- tag = FSM_ALU, FSM_LDM, FSM_STM
			- state = FSM_LOAD_OPERAND
		- If LDI, state = FSM_LDI
		- If JMP, state = FSM_JMP
		- If CALL, state = FSM_CALL
		- if RET, state = FSM_RET
		- if RETI, state = FSM_RETI
		- if SREG, state = FSM_SREG
	
	- (FSM_RETIRE) Typical ALU retire
		- FSM 1: (skip if no result) Store result DFF to target address via FSM_RAM, update flags if needed
		- FSM 1 or 2: Jump to FSM_FETCH 

	- (FSM_ALU) Typical (3OP/2OP) ALU opcode cycles
		- FSM 1: ALU opcode, store outcome to result DFF, indicate flags needing update, jump to FSM_RETIRE

	- (FSM_LDI) LDI opcode
		- FSM 1: Store IMM8 to result DFF, jump to FSM_RETIRE

	- (FSM_JMP) JMP opcodes
		- FSM 1: Update PC based on modifier and flags

	- (FSM_CALL) CALL opcode
		- FSM 1: Store PC[7:0] on stack (SRAM) via FSM_RAM
		- FSM 2: Store PC[15:8] on stack (SRAM) via FSM_RAM, set PC to IMM12

	- (FSM_RET/FSM_RETI) RET/RETI opcode
		- FSM 1: Load PC[15:8] from stack via FSM_RAM
		- FSM 2: Load PC[7:0] from stack via FSM_RAM

	- (FSM_LDM) LDM opcode
		- FSM 1: fetch data FSM_RAM 
			- Addressing modes:
				- opA != opB (two distinct registers), regA/regB form a 16-bit value
					if SREG[0] is true, then add RI to the address, and then post increment RI
				- opA == opB == 15 (same register both 15), SP + 0x2100 forms the address
		- FSM 2: Retire data via FSM_RETIRE, (increment SP if (opA == opB == 15)

	- (FSM_STM) STM opcode
		- FSM 1: store data FSM_RAM 
			- Addressing modes:
				- opA != opB, regD is stored to regA/regB forming a 16-bit address
					if SREG[1] is true, then add WI to the address, and then post increment WI
				- opA == opB == 15, SP + 0x20FF forms the address (pre-decrement), decrement SP

	- (FSM_SREG) Update status register
		- FSM 1: update status reg with imm8 (W1C for carry/zero, store for other bits)
			- if imm8[0] then zero out RI
			- if imm8[1] then zero out WI
		
	- Use a tag/state system so I can have common load/store from BRAM/SRAM
		- Likely overlay address/wren/data_in/data_out with BRAM/SRAM
			- use 14-bit address space where addresses 0..1FFF are BRAM and 2000..21FF are SRAM
			- the top module then just muxes the actual clock enable to the right block based on bit 14 of the address


	- (FSM_RAM) Typical FSM for load/store from RAM (BRAM/SRAM)
		- Cycle 1: Put enable=1,addr and [wren=0,data_in] or [wren=1) on the bus
		- Cycle N: "ready" is asserted, put enable=0 on the bus, (result DFF = data_out if reading)

Opcode map:

- Opcodes are 16-bits long using the top 4 bits to specify an instruction 
- Opcodes can either use 1 to 3 operands, 8-bit IMM or 12-bit IMM

So the formats would be

3OP  : 4-bit instruction, 4 bit regD, 4 bit regA, 4-bit regB
2OP: : 4-bit instruction, 4-bit regD, 4-bit modifier, 4-bit regA
8IMM : 4-bit instruction, 4 bit regD, 8-bit imm
12IMM: 4-bit instruction, 12-bit IMM
9SIMM: 4-bit instruction, 3-bit modifier, 9-bit signed value (divided by 2 since PC addresses are all even)

Instructions:
0 - Unused
1 - LDI (8IMM) R[d] = imm
2 - ADD (3OP)  R[d] = R[a] + R[b]								[ZC]
3 - ADC (3OP)  R[d] = R[a] + R[b] + carry						[ZC]
4 - SUB (3OP)  R[d] = R[a] - R[b]								[ZC]
5 - XOR (3OP)  R[d] = R[a] ^ R[b]								[ZC]
6 - AND (3OP)  R[d] = R[a] & R[b]								[ZC]
7 - OR (3OP)   R[d] = R[a] | R[b]								[ZC]
8 - Shifts (2OP)												[ZC]
	- 4 bit modifier
		- SHR  0: R[d] = R[a] >> 1
		- SAR  1: R[d] = signed(R[a]) >> 1
		- ROR  2: R[d] = R[a] >>> 1
		- ROL  3: R[d] = R[a] <<< 1
		- SWAP 4: R[d] = {R[a][3:0], R[a][7:4]}		
		- INC  5: R[d] = R[a] + 1
		- DEC  6: R[d] = R[a] - 1
		- NOT  7: R[d] = ~R[a]
9 - LDM (3OP)  R[d] = memory[{R[a], R[b]}]						[Z]
10 - STM (3OP)  memory[{R[a], R[b]}] = R[d]
11 - CALL (12IMM) PC = (IMM) << 1 (push PC)
12 - RET (12IMM) pop PC off stack
13 - Jumps (9SIMM) PC = PC + signed(SIMM) * 2 if condition met
	- 3-bit modifier
		- 0 JMP
		- 1 JC (carry)
		- 2 JNC
		- 3 JZ (zero)
		- 4 JNZ
14 - SRES (8-bit IMM) SREG = {SREG[7:6] & ~imm8[7:6], imm8[5:0]} (W1C the carry and zero flags, store the rest)
	- [0] - turn on read increment with LDM
	- [1] - turn on write increment with STM
	- [2] - set IRQ context (1 == in IRQ context, 0 == normal)
15 - RETI - pop PC off stack, return from interrupt

