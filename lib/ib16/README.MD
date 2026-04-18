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

   - Opcodes are 16-bits long using the top 4 bits to specify an instruction, "regD" is bits 11:8, regA is bits 7:4, regB is bits 3:0
   - Opcodes can either use 1 to 3 operands, 8-bit IMM or 12-bit IMM
   - Opcode format:
      - 3OP  : 4-bit instruction, 4 bit regD, 4 bit regA, 4-bit regB
      - 2OP: : 4-bit instruction, 4-bit regD, 4-bit modifier, 4-bit regA
      - 2OPALU: uses 4-bit regD as modifier, registers picked with 4-bit regA and 4-bit regB
      - 8IMM : 4-bit instruction, 4 bit regD, 8-bit imm
      - 12IMM: 4-bit instruction, 12-bit IMM
      - 9SIMM: 4-bit instruction, 3-bit modifier, 9-bit signed value (divided by 2 since PC addresses are all even)

### Instructions

```
0 - LDI (8IMM) R[d] = imm										[ZC]
1 - ADD (3OP)  R[d] = R[a] + R[b]								[ZC]
2 - ADC (3OP)  R[d] = R[a] + R[b] + carry						[ZC]
3 - XOR (3OP)  R[d] = R[a] ^ R[b]								[ZC]
4 - AND (3OP)  R[d] = R[a] & R[b]								[ZC]
5 - OR (3OP)   R[d] = R[a] | R[b]								[ZC]
6 - CMP (2OPALU) Carry = R[a] comparison R[b]					[C]    ; set's carry flag if comparison is true
	- R[d] values
		- 00: CMPLT R[a] < R[b]
		- 01: CMPEQ R[a] == R[b]
		- 10: CMPGT R[a] > R[b]
		- 11: Unused (C=0)
7 - Shifts (2OP)												[ZC]
	- 4 bit modifier
		- SHR  0: R[d] = R[a] >> 1								[ZC]
		- SAR  1: R[d] = signed(R[a]) >> 1						[ZC]
		- ROR  2: R[d] = {carry_flag, R[a] >> 1}, carry_flag = R[a][0]	[ZC]
		- ROL  3: R[d] = {R[a] << 1, carry_flag}, carry_flag = R[a][7] 	[ZC]
		- SWAP 4: R[d] = {R[a][3:0], R[a][7:4]}					[ZC]
		- INC  5: R[d] = R[a] + 1								[ZC]
		- DEC  6: R[d] = R[a] - 1								[ZC]
		- NOT  7: R[d] = ~R[a]									[ZC]
		- NEG  8: R[d] = -R[a]									[ZC]
		- SCC  9: R[d] = carry_flag								[Z]
		- SNZ 10: R[d] = zero_flag								[Z]
		- ROLB 11: R[d] = R[a] <<< 1							[ZC]
		- RORB 12: R[d] = R[a] >>> 1							[ZC]
8 - AJMP (2OPALU) PC = {R[a], R[b]}
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

### IRQ Support
The core supports an 8-bit IRQ pending port where when non-zero tells the core that it should jump to the IRQ
context.  In the IRQ context (same as using "SRES 4") a 2nd bank of registers is used that (so you don't have to worry about
clobbering application registers).  A return from interrupt opcode (RETI) switches the CPU back to app context.

The CPU will only jump to the ISR when performing a retire or fetch operation.  If it is mid instruction (including load/stores from
slow bus devices) IRQs will not be serviced.

Upon responding to an IRQ the following registers are saved: PC, SREG, Write Increment, Read Increment.  They are restored
once a RETI opcode is executed.  The stack pointer is not saved/restored and is also shared between the two contexts.  Any modificaton
to the stack pointer should be undone before issuing a RETI instruction.

It's up to the bus/soc fabric to decide how/what IRQs are triggered.  In my demos I use an int enable/pending system similar
to Atmel AVR microcontrollers.

## Assembler

The assembler is uh, best described as very basic.  It uses all upper case mnemonics, handles some white space and comments but that's about it.

Essentially the assembler has a buffer of the entire 64KB space and it starts at PC==0 inserting whatever opcodes or directives it sees.  When you
use .ORG to move the PC around you're just moving around in the buffer.

### Directives

   - .ORG <hex>
      - Change the current origin point in hex
   - .PROG_SIZE <hex>
      - The desired binary size by number of 16-bit words.
   - .BIN_START
   - .EQU <name> <value>
      - Define a constant with a given 'name' to a given hex value
   - .ALIGN <hex>
      - Make sure the current place in memory is aligned on the desired boundary
   - .DW <hex>
      - Place a constant value in memory
   - .DS '<string>'
      - Place a NUL terminated string contained between single quotes '' in memory at the current location
   - .DUP <hex>
      - Reserve the next amount of bytes (used for creating space for buffers)
   - .INC filename
      - Start compiling a new file right now before the next line of the current file

Lines starting with a ':' are a label.

Registers are specified just by number.  So r7 would be just '7'.  By convention the boot roms MUST set r0 to
0 when booting the user app.  While r0 is writable by the program it should be kept to 0 since it's handy for
a variety of uses.

### Opcodes

#### Three Operand ALU Opcodes

The three operand opcodes are **ADD**, **ADC**, **XOR**, **AND**, and **OR**.  They take three operands 'r', 'a', 'b' and
compute reg[d] = reg[a] OP reg[b].  For example

```
	ADD 2,3,4 ; r2 = r3 + r4
	AND 1,2,2 ; handy way of doing r1 = r2
```

#### Two Operand Opcodes

The two operand opcodes are **CMPLT**, **CMPEQ**, **CMPGT**, **SHR**, **SAR**, **ROR**, , **ROL**, , **SWAP**, , **INC**,
**DEC**, **NOT**, , **NEG**.  They take two operands 'a' and 'b'.

The comparisons compare reg[a] on the left of reg[b] and store the comparison in the carry flag.

```
   CMPLT 2,3  ; Sets carry if r2 < r3
   CMPEQ 7,6  ; Sets carry if r7 == r6
```

The shifts all work with reg[b] and store into reg[a].

   - **SHR**: R[a] = R[b] >> 1
   - **SAR**: R[a] = R[b] >>> 1 (the MSB carries downwards)
   - **ROR**: R[a] = (R[b] >> 1) | (carry_flag ? 0x80 : 0x00), carry_flag <= R[b][0]
   - **ROL**: R[a] = (R[b] << 1) | (carry_flag ? 1 : 0), carry_flag <= R[b][7]
   - **SWAP**: R[a] = nibble swap of R[b]
   - **INC**: R[a] = R[b] + 1
   - **DEC**: R[a] = R[b] + 1
   - **NOT**: R[a] = ~R[b]
   - **NEG**: R[a] = -R[b]

The instructions ROR and ROL are really meant for multibyte shifts.  You can emulate a ROL with something like 

```
   ADD 2,2,2 ; r2 = 2 * r2, carry = msb of r2
   ADC 2,2,0 ; r2 = 2 + carry completing the ROL
```

#### Other Opcodes

   - **LDI**: Takes a register and an 8-bit hex immediate, e.g. to put 0x5A into reg[3]: 'LDI 3,0x5A'
   - **LDM** and **STM**: Memory load and store
      - Take three operands 'd', 'a', and 'b'
      - Loads from the 16-bit address space using {reg[a],reg{b}} as the address
      - If a == b == 15 then it's a stack pop/push
      - Otherwise it's a memory operation
      - Loads or stores reg[d]
   - **AJMP**: Absolute jump to {R[a], R[b]}
   -  **LCALL**: Call to 16 byte aligned address in hex
   - **RET**: Return from subroutine
   - **RETI**: Return from interrupt
   - **JMP**, **JC**, **JNC**, **JZ**, **JNZ**: Jumps to 9 bit signed target
      - Jumps to 9-bit aligned word address relative to PC+2
   - **SRES**: Store 8 bit immediate in status register
      - bit 7 and 6 control the carry and zero flags (resp.) with a write-one-to-clear logic
      - bit 4 is written to jump to the boot rom
      - bit 3 is written to jump to the user app
      - bit 2 controls whether the CPU is in or out of the IRQ context (also disables IRQs from triggering if true)
      - bit 1 turns on the write increment
      - bit 0 turns on the read increment
      - Any write resets the read and write increment counters to 0. 

For pushing and popping the assembler has special pseudo opcodes:

```
PUSH 1    ; push r1 onto the stack
POP 1     ; pop r1 off the stack

STM 1,15,15 ; This is the actual opcode top push r1 onto the stack
LDM 1,15,15 ; and this is the actual opcode to pop r1
```

Loads and Stores can optionally use an 8-bit offset increments.  For LDM loads that
aren't pop operations bit 0 of SRES's operand controls whether the read increment is on.
When it is on successive LDM's will read from an increased address.  The counter is 8 bits but the additon is 16-bits.
When bit 1 of SRES is set the write increment is enabled.

```
SRES 3 ; enable both increments, resets them to ZERO
LDI 10,0x12
LDI 11,0x00  ; load r11:r10 to point to 0x1200
LDI 12,0x13
LDI 13,0x00  ; load r13:r12 to point to 0x1300
LDM 1,11,10  ; load from 0x1200
STM 1,13,12  ; store to 0x1300
LDM 1,11,10  ; load from 0x1201
STM 1,13,12  ; store to 0x1301
SRES 0 ; disable both increments
```

Using AJMP to make jump tables is done in a variety of ways but a simple route could be

```
   ; based on r1[1:0] jump to the correct handler
   LDI 2,0x03
   AND 2,2,3	; mask lower 2 bits
   ADD 1,1,1	; double it since each entry is 2-bytes long
   LDI 2,>OPTION0 ; load start of switch table
   LDI 3,<OPTION0
   ADD 2,2,1    ; add in index offset
   ADC 3,3,0    ; add carry
   AJMP 3,2		; jump to switch handler
:OPTION0
   JMP OPTION0_HANDLER
:OPTION1
   JMP OPTION1_HANDLER
:OPTION2
   JMP OPTION2_HANDLER
:OPTION3
   JMP OPTION3_HANDLER
:OPTION0_HANDLER
   ...
   JMP ENDIF
:OPTION1_HANDLER
   ...
   JMP ENDIF
:OPTION2_HANDLER
   ...
   JMP ENDIF
:OPTION3_HANDLER
   ...
   JMP ENDIF
:ENDIF
```

If you need larger case handlers you can make the stride of the table larger for instance

```
:OPTION0
   LDI 2,>OPTION0_HANDLER
   LDI 3,<OPTION0_HANDLER
   AJMP 3,2
...
```

Where you can do mult by 6 fairly easily

```
   ADD 2,1,1		; r2 = 2*r1
   ADD 1,2,1        ; r1 = 3*r1
   ADD 1,1,1        ; r1 = 2*3*r1 == 6*r1
```

#### Use of EQU and Labels

Any instruction that has a immediate (not register name) can use a label (line starting with :) or an .EQU constant

e.g.

```
.ORG 1000
:FUNC
.DW FUNC	 ; store 0x1000 at 0x1000
.EQU FOO 0x1234
.ORG FOO     ; move our current position to 0x1234, you can use symbols/labels here too
.DW FOO      ; store 0x1234 at 0x1234
```

There are special symbols for accessing byte halves of 16-bit value.  The '<' points to the top half, and '>' to the bottom, e.g.

```
.EQU FOO 0x1234

LDI 1,<FOO     ; store 0x12 in r1
LDI 2,>FOO     ; store 0x34 in r2
```

