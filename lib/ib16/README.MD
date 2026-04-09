# The IttyBitty RISC 8-bit'er.

## High level design

  - Simple 8-bit RISC CPU
  
  - 16-bit address space
  
  - Has 2 and 3-operand ALU opcodes removing the need to shuffle registers around
  
  - Any pair of registers can be used to form a 16-bit address for load/store
  
  - Designed for small size, tested on a Tang Nano 1K (GW1NZ-1) and a Lattice ECP5
  
  - Uses simple bus protocol allowing easy extension of the SoC by adding memory mapped peripherals.

## Demo configuration:

The ECP5 and Nano1K demos are similar but have a few differences

  - **Main Memory** maps from address 0000 upto XXXX (1FFF for Nano1K, `BLOCKS * 16'h800 for ECP5)
     - Stack is set to the last 256 bytes of RAM
     - ISR is set to the last 256 bytes before the stack

  - **Boot ROM** mapped to XXXX (2000 for Nano1K, F000 for ECP5)
     - Limited to 256 bytes
     - built into their respective top.v from the boot_rom*.v here
     
  - **MMIO**: (the map is the same for both demos but the Nano1K doesn't have GPIO1 mapped)
     - **Blocking UART**
         - Address: **0xFFFF**
     - **UART Status**
         - Address: **0xFFFE** (fifo empty, fifo full, rx ready) in the lower bits
     - **GPIO0**
         - Address: **0xFFFB** (8574 style tri-state 8-pin GPIO)
     - **GPIO1**
	     - Address: **0xFFFA** (8574 style tri-state 8-pin GPIO) (only on ECP5)
     - **TIMER**
         - Address: **0xFFF9**, the upper 8 bits of a 24-bit timer, in the default config is 1.213629ms per tick

  - **Video**
     - Text Buffer: 80x25 (2000 bytes) mapped to E800..EFFF on ECP5 only, uses IBM CP437 font supports all 256 symbols, rendered in 640x480 with y-stretching	


## Source code

   - **boot_rom.s**: can load upto 8192 - 256 bytes starting at 0000
      - waits for 5A (discards anything else)
      - then reads 1 byte, echos it back (only first 256 bytes), stores it in memory
   - **boot_rom_ecp5.s**: Boot loader for ECP5 uses GPIO0 to indicate progress 
      - waits for 5A (discards anything else)
      - then reads 1 byte, echos it back (only first 256 bytes), stores it in memory
   - **nano1k_demo.s**:
      - Simple demo that just prints a string repeatedly.
   - **ecp5_demo.s**:
      - Growing demo that uses console (vga) output as well as timer and uart and gpio

## Opcode map

  - **Registers**
     - **PC** - 16 bits (counts 16-bit words so you fetch from memory[PC*2])
     - **SP** - 8 bits starts at 100 in SRAM (overall address 2100) and counts up
     - **WI** - 8 bits write index (used by STM if SREG[1] is set)
     - **RI** - 8 bits read index (used by LDM if SREG[0] is set) 
     - **SREG** - 8 bits (Carry, Zero, unused, reboot to ROM, Boot to APP, Mask IRQ, Write Increment, Read Increment)
     - **0, 1, 2, 3, ... ,15** - GPRs, r0 is writable, the ROM guarantees your app boots with r0 == 0 so you can use it for ADC/comparisons, etc.

   - Opcodes are 16-bits long using the top 4 bits to specify an instruction 
   - Opcodes can either use 1 to 3 operands, 8-bit IMM or 12-bit IMM
   - Opcode format:
      - 3OP  : 4-bit instruction, 4 bit regD, 4 bit regA, 4-bit regB
      - 2OP: : 4-bit instruction, 4-bit regD, 4-bit modifier, 4-bit regA
      - 8IMM : 4-bit instruction, 4 bit regD, 8-bit imm
      - 12IMM: 4-bit instruction, 12-bit IMM
      - 9SIMM: 4-bit instruction, 3-bit modifier, 9-bit signed value (divided by 2 since PC addresses are all even)

### Instructions

```
0 - LDI (8IMM) R[d] = imm										[ZC]
1 - ADD (3OP)  R[d] = R[a] + R[b]								[ZC]
2 - ADC (3OP)  R[d] = R[a] + R[b] + carry						[ZC]
3 - SUB (3OP)  R[d] = R[a] - R[b]								[ZC]
4 - XOR (3OP)  R[d] = R[a] ^ R[b]								[ZC]
5 - AND (3OP)  R[d] = R[a] & R[b]								[ZC]
6 - OR (3OP)   R[d] = R[a] | R[b]								[ZC]
7 - CMP (2OPALU) Carry = R[a] comparison R[b]					[C]    ; set's carry flag if comparison is true
	- R[d] values
		- 00: R[a] < R[b]
		- 01: R[a] == R[b]
		- 10: R[a] > R[b]
		- 11: Unused (C=0)
8 - Shifts (2OP)												[ZC]
	- 4 bit modifier
		- SHR  0: R[d] = R[a] >> 1								[ZC]
		- SAR  1: R[d] = signed(R[a]) >> 1						[ZC]
		- ROR  2: R[d] = R[a] >>> 1								[ZC]
		- ROL  3: R[d] = R[a] <<< 1								[ZC]
		- SWAP 4: R[d] = {R[a][3:0], R[a][7:4]}					[ZC]
		- INC  5: R[d] = R[a] + 1								[ZC]
		- DEC  6: R[d] = R[a] - 1								[ZC]
		- NOT  7: R[d] = ~R[a]									[ZC]
9 - LDM (3OP)  R[d] = memory[{R[a], R[b]}]						[ZC]  (if a == b == 15 then it's a pop or push off the stack)
10 - STM (3OP)  memory[{R[a], R[b]}] = R[d]
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
	- [0] - turn on read increment with LDM (SRES opcode resets RI/WI to zero)
	- [1] - turn on write increment with STM
	- [2] - set IRQ context (1 == in IRQ context, 0 == normal)
	- [3] - Write 1 to boot APP (at PC=0000)
15 - RETI - pop PC off stack, return from interrupt
```
