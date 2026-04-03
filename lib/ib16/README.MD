The IttyBitty RISC 8-bit'er.

High level design

- upto 64Kbyte RAM for code/data
- multi cycle single issue non-pipelined (averages about 6-8 clocks per instruction)
- Meant for 1K LUT4 FPGAs :-) (mostly tested on a Tang Nano 1K)
- Carry and Zero flags (only updated by ALU opcodes)
	- use a 9-bit "result DFF" so ALU opcodes can spill into bit 9 for carry flag
- Uses bus handshaking allowing arbitrary cycles per access memory devices

Demo configuration:
- BRAM is organized as follows
   - 0000..1FFF: General data/code
		- if using interrupts then the ISR begins at 1F00
   
- BOOT ROM:
	- at 2000...20FF
	- built into top.v demo

- MMIO:
   - Blocking UART: 0xFFFF
   - UART Status  : 0xFFFE (fifo empty, fifo full, rx ready) in the lower bits
   - GPIO		  : 0xFFFB (8574 style tri-state 8-pin GPIO)
   - TIMER		  : 0xFFFA, the upper 8 bits of a 24-bit timer, in the default config is 1.213629ms per tick

- Registers
   - PC - 16 bits (counts 16-bit words so you fetch from memory[PC*2])
   - SP - 8 bits starts at 100 in SRAM (overall address 2100) and counts up
   - WI - 8 bits write index (used by STM if SREG[1] is set)
   - RI - 8 bits read index (used by LDM if SREG[0] is set) 
   - SREG - 8 bits (Carry, Zero, unused, unused, Boot to APP, Mask IRQ, Write Increment, Read Increment)

- Source code:
	- boot_rom.s can load upto 8192 - 256 bytes starting at 0000
		- waits for 5A (discards anything else)
		- then reads 1 byte, echos it back, stores it in memory
	- uart_demo.s
		- On Tang Nano 1K: this increments the GPIO pins periodically making the RGB leds blink, 
		- Has IRQ for uart, echos back what it receives from ISR

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
0 - LDI (8IMM) R[d] = imm
1 - ADD (3OP)  R[d] = R[a] + R[b]								[ZC]
2 - ADC (3OP)  R[d] = R[a] + R[b] + carry						[ZC]
3 - SUB (3OP)  R[d] = R[a] - R[b]								[ZC]
4 - XOR (3OP)  R[d] = R[a] ^ R[b]								[ZC]
5 - AND (3OP)  R[d] = R[a] & R[b]								[ZC]
6 - OR (3OP)   R[d] = R[a] | R[b]								[ZC]
7 - Shifts (2OP)												[ZC]
	- 4 bit modifier
		- SHR  0: R[d] = R[a] >> 1								[ZC]
		- SAR  1: R[d] = signed(R[a]) >> 1						[ZC]
		- ROR  2: R[d] = R[a] >>> 1								[ZC]
		- ROL  3: R[d] = R[a] <<< 1								[ZC]
		- SWAP 4: R[d] = {R[a][3:0], R[a][7:4]}					[ZC]
		- INC  5: R[d] = R[a] + 1								[ZC]
		- DEC  6: R[d] = R[a] - 1								[ZC]
		- NOT  7: R[d] = ~R[a]									[ZC]
8 - LDM (3OP)  R[d] = memory[{R[a], R[b]}]						[Z]  (if a == b == 15 then it's a pop or push off the stack)
9 - STM (3OP)  memory[{R[a], R[b]}] = R[d]
10 - Unused
11 - LCAL (12IMM) PC = (12IMM) << 4 (push PC)
12 - RET pop PC off stack
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
	- [3] - Write 1 to boot APP (at PC=0000)
15 - RETI - pop PC off stack, return from interrupt

