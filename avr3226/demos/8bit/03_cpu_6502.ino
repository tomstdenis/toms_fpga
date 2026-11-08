#ifdef CPU_6502

static struct {
	uint8_t regA, regX, regY, regSR, regSP, ints;
	uint16_t regPC, oldPC;
} cpu6502;

// count cpu cycles you can comment this out if you want
#define COUNT(c) cpu_cycles += (c)

#ifndef COUNT
	#define COUNT(c)
#endif

//#define TRACE
//#define HOSTPC

#ifdef TRACE
#ifdef HOSTPC
#define LOG printw
#include <ncurses.h>
void trace_6502(void)
{
	printw("CPU{PC=%04x,A=%02x,X=%02x,Y=%02X,SR=%02x,SP=%02x} ",
		cpu6502.regPC, cpu6502.regA, cpu6502.regX, cpu6502.regY, cpu6502.regSR, cpu6502.regSP);
}
#else
void trace_6502(void)
{
}
#endif
#else
#define LOG(...)
#endif

#define FLAGS_N 0x80
#define FLAGS_V 0x40
#define FLAGS_B 0x10
#define FLAGS_D 0x08
#define FLAGS_I 0x04
#define FLAGS_Z 0x02
#define FLAGS_C 0x01

void reset_6502(void)
{
	memset(&cpu6502, 0, sizeof cpu6502);
	cpu6502.regSR |= FLAGS_D; // decimal mode flag is default on reset
	cache_invalidate();
	cpu6502.ints |= CPU_SIG_RESET;
	cpu6502.regSP = 0xFF;
}

void jump_6502(cache_addr_t target)
{
	cpu6502.regPC = target;
}

uint16_t save_6502(uint16_t offset)
{
	mem_write_block(MEM_PAGE_TO_OFFSET(MEM_PAGE_SAVE_SLOT) + offset, sizeof cpu6502, (uint8_t *)&cpu6502);
	return offset + sizeof(cpu6502);
}

uint16_t load_6502(uint16_t offset)
{
	mem_read_block(MEM_PAGE_TO_OFFSET(MEM_PAGE_SAVE_SLOT) + offset, sizeof cpu6502, (uint8_t *)&cpu6502);
	return offset + sizeof(cpu6502);
}

void init_6502()
{
	reset_6502();
}

void int_6502(uint8_t sig)
{
	cpu6502.ints |= sig;
}

static void update_NZ(uint8_t val)
{
	cpu6502.regSR &= ~(FLAGS_N | FLAGS_Z); // clear NZ bits
	cpu6502.regSR |= (val & FLAGS_N);   // N bit is MSB of result
	cpu6502.regSR |= ((val & 0xFF) ? 0x00 : FLAGS_Z); // Z bit is !val
}

static void update_NZC(uint16_t val)
{
	cpu6502.regSR &= ~(FLAGS_N | FLAGS_Z | FLAGS_C); // clear NZC bits
	cpu6502.regSR |= (val & FLAGS_N);   // N bit is MSB of result
	cpu6502.regSR |= ((val & 0xFF) ? 0x00 : FLAGS_Z); // Z bit is !val
	cpu6502.regSR |= ((val & 0x100) >> 8); // C bit
}

static void update_NZC2(uint16_t val)
{
	cpu6502.regSR &= ~(FLAGS_N | FLAGS_Z | FLAGS_C); // clear NZC bits
	cpu6502.regSR |= (val & FLAGS_N);   // N bit is MSB of result
	cpu6502.regSR |= ((val & 0xFF) ? 0x00 : FLAGS_Z); // Z bit is !val
	cpu6502.regSR |= (((val ^ 0x100) & 0x100) >> 8); // C bit
}

static void update_NZCV(uint16_t val, uint8_t val1, uint8_t val2)
{
	cpu6502.regSR &= ~(FLAGS_N | FLAGS_V | FLAGS_Z | FLAGS_C); // clear NZCV bits
	cpu6502.regSR |= (val & FLAGS_N);   // N bit is MSB of result
	cpu6502.regSR |= ((val & 0xFF) ? 0x00 : FLAGS_Z); // Z bit is !val
	cpu6502.regSR |= ((val & 0x100) >> 8); // C bit
	cpu6502.regSR |= ((val1 ^ val2 ^ 0x80) & (val1 ^ val) & 0x80) >> 1; // oVerflow set if op1/op2 are the same sign and result has diff sign
}

static void do_adc(uint8_t val1, uint8_t val2)
{
	uint16_t res;
	if (cpu6502.regSR & FLAGS_D) {
		// BCD math
		uint16_t res2;
		res = (val1 & 0xF) + (val2 & 0xF) + (cpu6502.regSR & FLAGS_C);
		if (res > 9) {
			res -= 10;
			res2 = 1;
		} else {
			res2 = 0;
		}
		res2 = (val1 >> 4) + (val2 >> 4) + res2;
		if (res2 > 9) {
			res2 -= 10;
			cpu6502.regSR |= FLAGS_C;
		} else {
			cpu6502.regSR &= ~FLAGS_C;
		}
		cpu6502.regA = (res2 << 4) | res;
		update_NZ(cpu6502.regA);
	} else {
		res = (uint16_t)val1 + val2 + (cpu6502.regSR & FLAGS_C);
		cpu6502.regA = res;
		update_NZCV(res, val1, val2);
	}
}

static void do_sbc(uint8_t val1, uint8_t val2)
{
	uint16_t res;
	if (cpu6502.regSR & FLAGS_D) {
		// BCD math
		uint16_t res2;
		res = (val1 & 0xF) - (val2 & 0xF) - (1 ^ (cpu6502.regSR & FLAGS_C));
		if (res > 9) {
			res += 10;
			res2 = 0;
		} else {
			res2 = 1;
		}
		res2 = (val1 >> 4) - (val2 >> 4) - res2;
		if (res2 > 9) {
			res2 += 10;
			cpu6502.regSR |= FLAGS_C;
		} else {
			cpu6502.regSR &= ~FLAGS_C;
		}
		cpu6502.regA = (res2 << 4) | res;
		update_NZ(cpu6502.regA);
	} else {
		res = (uint16_t)val1 - val2 - (1 ^ (cpu6502.regSR & FLAGS_C));
		cpu6502.regA = res;
		update_NZCV(res ^ 0x100, val1, val2); // invert carry flag...
	}
}

void step_6502(uint16_t steps)
{
	uint16_t
		res, X, Y,
		addr;
	uint8_t
		val1, val2,
		opcode;

	while (steps--) {
	// handle interrupts
		if (cpu6502.ints & CPU_SIG_NMI) {
			cpu6502.ints &= ~CPU_SIG_NMI;
			// push PC
				cache_write_byte(0x100 + (cpu6502.regSP--), cpu6502.regPC >> 8);
				cache_write_byte(0x100 + (cpu6502.regSP--), cpu6502.regPC & 0xFF);
			// push SR
				cache_write_byte(0x100 + (cpu6502.regSP--), cpu6502.regSR);
			cpu6502.regPC = cache_read_word(0xFFFA);
		} else if (cpu6502.ints & CPU_SIG_RESET) {
			cpu6502.ints &= ~CPU_SIG_RESET;
			cpu6502.regPC = cache_read_word(0xFFFC);
		} else if ((cpu6502.ints & CPU_SIG_IRQ) && !(cpu6502.regSR & FLAGS_I)) {
			cpu6502.ints &= ~CPU_SIG_IRQ;
			// push PC
				cache_write_byte(0x100 + (cpu6502.regSP--), cpu6502.regPC >> 8);
				cache_write_byte(0x100 + (cpu6502.regSP--), cpu6502.regPC & 0xFF);
			// push SR
				cache_write_byte(0x100 + (cpu6502.regSP--), cpu6502.regSR);
			cpu6502.regPC = cache_read_word(0xFFFE);
		}

		opcode = cache_read_byte(cpu6502.regPC++); // read the current opcode byte

	#ifdef TRACE
		trace_6502();
	#endif
		LOG("step_6502: (%04x) => %02x\n", cpu6502.regPC-1, opcode);


		// val1 is usually A...
		val1 = cpu6502.regA;

		switch (opcode) {
			// ADC opcodes
			case 0x69: // ADC #oper
				val2 = cache_read_byte(cpu6502.regPC++);
				do_adc(val1, val2);
				COUNT(2);
				break;
			case 0x65: // ADC $zp
				val2 = cache_read_byte(cache_read_byte(cpu6502.regPC++));
				do_adc(val1, val2);
				COUNT(3);
				break;
			case 0x75: // ADC zp,X
				val2 = cache_read_byte((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF);
				do_adc(val1, val2);
				COUNT(4);
				break;
			case 0x6D: // ADC $oper
				val2 = cache_read_byte(cache_read_word(cpu6502.regPC));
				cpu6502.regPC += 2;
				do_adc(val1, val2);
				COUNT(4);
				break;
			case 0x7D: // ADC $oper,X
				val2 = cache_read_byte(X = (Y = cache_read_word(cpu6502.regPC)) + cpu6502.regX);
				cpu6502.regPC += 2;
				do_adc(val1, val2);
				if ((X ^ Y) & 0xFF00) {
					COUNT(5);
				} else {
					COUNT(4);
				}
				break;
			case 0x79: // ADC $oper,Y
				val2 = cache_read_byte(X = (Y = cache_read_word(cpu6502.regPC)) + cpu6502.regY);
				cpu6502.regPC += 2;
				do_adc(val1, val2);
				if ((X ^ Y) & 0xFF00) {
					COUNT(5);
				} else {
					COUNT(4);
				}
				break;
			case 0x61: // ADC ($oper,X)
				val2 = cache_read_byte(cache_read_word((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF));
				do_adc(val1, val2);
				COUNT(6);
				break;
			case 0x71: // ADC ($oper),Y
				val2 = cache_read_byte(X = (Y = cache_read_word(cache_read_byte(cpu6502.regPC++))) + cpu6502.regY);
				do_adc(val1, val2);
				if ((X ^ Y) & 0xFF00) {
					COUNT(6);
				} else {
					COUNT(5);
				}
				break;

			// AND opcodes
			case 0x29: // AND #oper
				update_NZ(cpu6502.regA &= cache_read_byte(cpu6502.regPC++));
				COUNT(2);
				break;
			case 0x25: // AND $zp
				update_NZ(cpu6502.regA &= cache_read_byte(cache_read_byte(cpu6502.regPC++)));
				COUNT(3);
				break;
			case 0x35: // AND zp,X
				update_NZ(cpu6502.regA &= cache_read_byte((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF));
				COUNT(4);
				break;
			case 0x2D: // AND $oper
				update_NZ(cpu6502.regA &= cache_read_byte(cache_read_word(cpu6502.regPC)));
				cpu6502.regPC += 2;
				COUNT(4);
				break;
			case 0x3D: // AND $oper,X
				update_NZ(cpu6502.regA &= cache_read_byte(X = (Y = cache_read_word(cpu6502.regPC)) + cpu6502.regX));
				cpu6502.regPC += 2;
				if ((X ^ Y) & 0xFF00) {
					COUNT(5);
				} else {
					COUNT(4);
				}
				break;
			case 0x39: // AND $oper,Y
				update_NZ(cpu6502.regA &= cache_read_byte(X = (Y = cache_read_word(cpu6502.regPC)) + cpu6502.regY));
				cpu6502.regPC += 2;
				if ((X ^ Y) & 0xFF00) {
					COUNT(5);
				} else {
					COUNT(4);
				}
				break;
			case 0x21: // AND ($oper,X)
				update_NZ(cpu6502.regA &= cache_read_byte(cache_read_word((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF)));
				COUNT(6);
				break;
			case 0x31: // AND ($oper),Y
				update_NZ(cpu6502.regA &= cache_read_byte(X = (Y = cache_read_word(cache_read_byte(cpu6502.regPC++))) + cpu6502.regY));
				if ((X ^ Y) & 0xFF00) {
					COUNT(6);
				} else {
					COUNT(5);
				}
				break;

			// ASL opcodes
			case 0x0A: // ASL A
				res = (uint16_t)cpu6502.regA << 1;
				cpu6502.regA = res;
				update_NZC(res);
				COUNT(2);
				break;
			case 0x06: // ASL $zp
				res = (uint16_t)cache_read_byte(addr = cache_read_byte(cpu6502.regPC++)) << 1;
				cache_write_byte(addr, res);
				update_NZC(res);
				COUNT(5);
				break;
			case 0x16: // ASL zp,X
				res = (uint16_t)cache_read_byte(addr = ((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF)) << 1;
				cache_write_byte(addr, res);
				update_NZC(res);
				COUNT(6);
				break;
			case 0x0E: // ASL $oper
				res = (uint16_t)cache_read_byte(addr = cache_read_word(cpu6502.regPC)) << 1;
				cache_write_byte(addr, res);
				update_NZC(res);
				cpu6502.regPC += 2;
				COUNT(6);
				break;
			case 0x1E: // ASL $oper,X
				res = (uint16_t)cache_read_byte(addr = cache_read_word(cpu6502.regPC) + cpu6502.regX) << 1;
				cache_write_byte(addr, res);
				update_NZC(res);
				cpu6502.regPC += 2;
				COUNT(7);
				break;

			case 0x24: // BIT $zp
				val1 = cache_read_byte(cache_read_byte(cpu6502.regPC++));
				COUNT(3);
				goto BIT_val;
			case 0x2C: // BIT $oper
				val1 = cache_read_byte(cache_read_word(cpu6502.regPC));
				cpu6502.regPC += 2;
				COUNT(4);
	BIT_val:
				cpu6502.regSR &= ~(FLAGS_N | FLAGS_V | FLAGS_Z);
				cpu6502.regSR |= (cpu6502.regA & val1) ? 0 : FLAGS_Z;
				cpu6502.regSR |= val1 & (0x80 | 0x40);
				break;

			case 0x00: // BRK
				addr = cpu6502.regPC + 2;
				cache_write_byte(0x100 + (cpu6502.regSP-- & 0xFF), (addr  >> 8) & 0xFF);
				cache_write_byte(0x100 + (cpu6502.regSP-- & 0xFF), addr & 0xFF);
				// 2. Push SR with Break flag set
				cache_write_byte(0x100 + (cpu6502.regSP-- & 0xFF), cpu6502.regSR | FLAGS_B);
				// 3. Set Interrupt disable and Jump to IRQ/BRK vector
				cpu6502.regSR |= FLAGS_I;
				cpu6502.regPC = cache_read_word(0xFFFE);
				COUNT(7);
				break;

			// branches
			case 0x90: // BCC
				if (!(cpu6502.regSR & FLAGS_C)) {
					addr = (uint16_t)(cache_read_byte(cpu6502.regPC++) ^ 0x80) - 0x80; // sign extend 'relative'
					res = cpu6502.regPC;
					cpu6502.regPC += addr;
					if ((res ^ cpu6502.regPC) & 0xFF00) {
						COUNT(4);
					} else {
						COUNT(3);
					}
				} else {
					++cpu6502.regPC;
					COUNT(2);
				}
				break;
			case 0xB0: // BCS
				if ((cpu6502.regSR & FLAGS_C)) {
					addr = (uint16_t)(cache_read_byte(cpu6502.regPC++) ^ 0x80) - 0x80; // sign extend 'relative'
					res = cpu6502.regPC;
					cpu6502.regPC += addr;
					if ((res ^ cpu6502.regPC) & 0xFF00) {
						COUNT(4);
					} else {
						COUNT(3);
					}
				} else {
					++cpu6502.regPC;
					COUNT(2);
				}
				break;
			case 0xF0: // BEQ
				if ((cpu6502.regSR & FLAGS_Z)) {
					addr = (uint16_t)(cache_read_byte(cpu6502.regPC++) ^ 0x80) - 0x80; // sign extend 'relative'
					res = cpu6502.regPC;
					cpu6502.regPC += addr;
					if ((res ^ cpu6502.regPC) & 0xFF00) {
						COUNT(4);
					} else {
						COUNT(3);
					}
				} else {
					++cpu6502.regPC;
					COUNT(2);
				}
				break;
			case 0x30: // BMI
				if ((cpu6502.regSR & FLAGS_N)) {
					addr = (uint16_t)(cache_read_byte(cpu6502.regPC++) ^ 0x80) - 0x80; // sign extend 'relative'
					res = cpu6502.regPC;
					cpu6502.regPC += addr;
					if ((res ^ cpu6502.regPC) & 0xFF00) {
						COUNT(4);
					} else {
						COUNT(3);
					}
				} else {
					++cpu6502.regPC;
					COUNT(2);
				}
				break;
			case 0xD0: // BNE
				if (!(cpu6502.regSR & FLAGS_Z)) {
					addr = (uint16_t)(cache_read_byte(cpu6502.regPC++) ^ 0x80) - 0x80; // sign extend 'relative'
					res = cpu6502.regPC;
					cpu6502.regPC += addr;
					if ((res ^ cpu6502.regPC) & 0xFF00) {
						COUNT(4);
					} else {
						COUNT(3);
					}
				} else {
					++cpu6502.regPC;
					COUNT(2);
				}
				break;
			case 0x10: // BPL
				if (!(cpu6502.regSR & FLAGS_N)) {
					addr = (uint16_t)(cache_read_byte(cpu6502.regPC++) ^ 0x80) - 0x80; // sign extend 'relative'
					res = cpu6502.regPC;
					cpu6502.regPC += addr;
					if ((res ^ cpu6502.regPC) & 0xFF00) {
						COUNT(4);
					} else {
						COUNT(3);
					}
				} else {
					++cpu6502.regPC;
					COUNT(2);
				}
				break;
			case 0x50: // BVC
				if (!(cpu6502.regSR & FLAGS_V)) {
					addr = (uint16_t)(cache_read_byte(cpu6502.regPC++) ^ 0x80) - 0x80; // sign extend 'relative'
					res = cpu6502.regPC;
					cpu6502.regPC += addr;
					if ((res ^ cpu6502.regPC) & 0xFF00) {
						COUNT(4);
					} else {
						COUNT(3);
					}
				} else {
					++cpu6502.regPC;
					COUNT(2);
				}
				break;
			case 0x70: // BVS
				if ((cpu6502.regSR & FLAGS_V)) {
					addr = (uint16_t)(cache_read_byte(cpu6502.regPC++) ^ 0x80) - 0x80; // sign extend 'relative'
					res = cpu6502.regPC;
					cpu6502.regPC += addr;
					if ((res ^ cpu6502.regPC) & 0xFF00) {
						COUNT(4);
					} else {
						COUNT(3);
					}
				} else {
					++cpu6502.regPC;
					COUNT(2);
				}
				break;

			case 0x18: // CLC
				cpu6502.regSR &= ~FLAGS_C;
				COUNT(2);
				break;
			case 0xD8: // CLD
				cpu6502.regSR &= ~FLAGS_D;
				COUNT(2);
				break;
			case 0x58: // CLI
				cpu6502.regSR &= ~FLAGS_I;
				COUNT(2);
				break;
			case 0xB8: // CLV
				cpu6502.regSR &= ~FLAGS_V;
				COUNT(2);
				break;

			// CMP opcodes
			case 0xC9: //CMP #oper
				update_NZC2((uint16_t)cpu6502.regA - cache_read_byte(cpu6502.regPC++));
				COUNT(2);
				break;
			case 0xC5: //CMP $zp
				update_NZC2((uint16_t)cpu6502.regA - cache_read_byte(cache_read_byte(cpu6502.regPC++)));
				COUNT(3);
				break;
			case 0xD5: //CMP zp,X
				update_NZC2((uint16_t)cpu6502.regA - cache_read_byte((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF));
				COUNT(4);
				break;
			case 0xCD: //CMP $oper
				update_NZC2((uint16_t)cpu6502.regA - cache_read_byte(cache_read_word(cpu6502.regPC)));
				cpu6502.regPC += 2;
				COUNT(4);
				break;
			case 0xDD: //CMP $oper,X
				update_NZC2((uint16_t)cpu6502.regA - cache_read_byte(X = (Y = cache_read_word(cpu6502.regPC)) + cpu6502.regX));
				cpu6502.regPC += 2;
				if ((X ^ Y) & 0xFF00) {
					COUNT(5);
				} else {
					COUNT(4);
				}
				break;
			case 0xD9: //CMP $oper,Y
				update_NZC2((uint16_t)cpu6502.regA - cache_read_byte(X = (Y = cache_read_word(cpu6502.regPC)) + cpu6502.regY));
				cpu6502.regPC += 2;
				if ((X ^ Y) & 0xFF00) {
					COUNT(5);
				} else {
					COUNT(4);
				}
				break;
			case 0xC1: // CMP ($oper,X)
				update_NZC2((uint16_t)cpu6502.regA - cache_read_byte(cache_read_word((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF)));
				COUNT(6);
				break;
			case 0xD1: // CMP ($oper),Y
				update_NZC2((uint16_t)cpu6502.regA - cache_read_byte(X = (Y = cache_read_word(cache_read_byte(cpu6502.regPC++))) + cpu6502.regY));
				if ((X ^ Y) & 0xFF00) {
					COUNT(6);
				} else {
					COUNT(5);
				}
				break;

			case 0xE0: //CPX #oper
				update_NZC2((uint16_t)cpu6502.regX - cache_read_byte(cpu6502.regPC++));
				COUNT(2);
				break;
			case 0xE4: //CPX $zp
				update_NZC2((uint16_t)cpu6502.regX - cache_read_byte(cache_read_byte(cpu6502.regPC++)));
				COUNT(3);
				break;
			case 0xEC: //CPX $oper
				update_NZC2((uint16_t)cpu6502.regX - cache_read_byte(cache_read_word(cpu6502.regPC)));
				cpu6502.regPC += 2;
				COUNT(4);
				break;

			case 0xC0: //CPY #oper
				update_NZC2((uint16_t)cpu6502.regY - cache_read_byte(cpu6502.regPC++));
				COUNT(2);
				break;
			case 0xC4: //CPY $zp
				update_NZC2((uint16_t)cpu6502.regY - cache_read_byte(cache_read_byte(cpu6502.regPC++)));
				COUNT(3);
				break;
			case 0xCC: //CPY $oper
				update_NZC2((uint16_t)cpu6502.regY - cache_read_byte(cache_read_word(cpu6502.regPC)));
				cpu6502.regPC += 2;
				COUNT(4);
				break;

			// DEC opcodes
			case 0xC6: //DEC $zp
				res = cache_read_byte(addr = cache_read_byte(cpu6502.regPC++)) - 1;
				cache_write_byte(addr, res);
				update_NZ(res);
				COUNT(5);
				break;
			case 0xD6: //DEC $zp,X
				res = cache_read_byte(addr = ((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF)) - 1;
				cache_write_byte(addr, res);
				update_NZ(res);
				COUNT(6);
				break;
			case 0xCE: //DEC $oper
				res = cache_read_byte(addr = cache_read_word(cpu6502.regPC)) - 1;
				cpu6502.regPC += 2;
				cache_write_byte(addr, res);
				update_NZ(res);
				COUNT(6);
				break;
			case 0xDE: //DEC $oper,X
				res = cache_read_byte(addr = cache_read_word(cpu6502.regPC) + cpu6502.regX) - 1;
				cpu6502.regPC += 2;
				cache_write_byte(addr, res);
				update_NZ(res);
				COUNT(7);
				break;

			case 0xCA: // DEX
				update_NZ(cpu6502.regX -= 1);
				COUNT(2);
				break;
			case 0x88: // DEY
				update_NZ(cpu6502.regY -= 1);
				COUNT(2);
				break;

			// EOR opcodes
			case 0x49: // EOR #oper
				update_NZ(cpu6502.regA ^= cache_read_byte(cpu6502.regPC++));
				COUNT(2);
				break;
			case 0x45: // EOR $zp
				update_NZ(cpu6502.regA ^= cache_read_byte(cache_read_byte(cpu6502.regPC++)));
				COUNT(3);
				break;
			case 0x55: // EOR zp,X
				update_NZ(cpu6502.regA ^= cache_read_byte((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF));
				COUNT(4);
				break;
			case 0x4D: // EOR $oper
				update_NZ(cpu6502.regA ^= cache_read_byte(cache_read_word(cpu6502.regPC)));
				cpu6502.regPC += 2;
				COUNT(4);
				break;
			case 0x5D: // EOR $oper,X
				update_NZ(cpu6502.regA ^= cache_read_byte(X = (Y = cache_read_word(cpu6502.regPC)) + cpu6502.regX));
				cpu6502.regPC += 2;
				if ((X ^ Y) & 0xFF00) {
					COUNT(5);
				} else {
					COUNT(4);
				}
				break;
			case 0x59: // EOR $oper,Y
				update_NZ(cpu6502.regA ^= cache_read_byte(X = (Y = cache_read_word(cpu6502.regPC)) + cpu6502.regY));
				cpu6502.regPC += 2;
				if ((X ^ Y) & 0xFF00) {
					COUNT(5);
				} else {
					COUNT(4);
				}
				break;
			case 0x41: // EOR ($oper,X)
				update_NZ(cpu6502.regA ^= cache_read_byte(cache_read_word((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF)));
				COUNT(6);
				break;
			case 0x51: // EOR ($oper),Y
				update_NZ(cpu6502.regA ^= cache_read_byte(X = (Y = cache_read_word(cache_read_byte(cpu6502.regPC++))) + cpu6502.regY));
				if ((X ^ Y) & 0xFF00) {
					COUNT(6);
				} else {
					COUNT(5);
				}
				break;

			// INC opcodes
			case 0xE6: //INC $zp
				res = cache_read_byte(addr = cache_read_byte(cpu6502.regPC++)) + 1;
				cache_write_byte(addr, res);
				update_NZ(res);
				COUNT(5);
				break;
			case 0xF6: //INC $zp,X
				res = cache_read_byte(addr = ((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF)) + 1;
				cache_write_byte(addr, res);
				update_NZ(res);
				COUNT(6);
				break;
			case 0xEE: //INC $oper
				res = cache_read_byte(addr = cache_read_word(cpu6502.regPC)) + 1;
				cpu6502.regPC += 2;
				cache_write_byte(addr, res);
				update_NZ(res);
				COUNT(6);
				break;
			case 0xFE: //INC $oper,X
				res = cache_read_byte(addr = cache_read_word(cpu6502.regPC) + cpu6502.regX) + 1;
				cpu6502.regPC += 2;
				cache_write_byte(addr, res);
				update_NZ(res);
				COUNT(7);
				break;

			case 0xE8: // INX
				update_NZ(cpu6502.regX += 1);
				COUNT(2);
				break;
			case 0xC8: // INY
				update_NZ(cpu6502.regY += 1);
				COUNT(2);
				break;

			// JMP
			case 0x4C: // JMP $oper
				cpu6502.regPC = cache_read_word(cpu6502.regPC);
				COUNT(3);
				break;
			case 0x6C: // JMP ($OPER)
				addr = cache_read_word(cpu6502.regPC);
				if ((addr & 0xFF) == 0xFF) {
					// JMP ($oper) doesn't do 16-bit math on $oper
					cpu6502.regPC = cache_read_byte(addr) | ((uint16_t)cache_read_byte(addr & 0xFF00) << 8);
				} else {
					cpu6502.regPC = cache_read_word(addr);
				}
				COUNT(5);
				break;

			case 0x20: // JSR $oper
				addr = cpu6502.regPC + 1; // Address of the LAST byte of the JSR instruction
				// Push HI then LO
				cache_write_byte(0x100 + (cpu6502.regSP-- & 0xFF), (addr >> 8) & 0xFF);
				cache_write_byte(0x100 + (cpu6502.regSP-- & 0xFF), addr & 0xFF);
				cpu6502.regPC = cache_read_word(cpu6502.regPC);
				COUNT(6);
				break;

			// LDA opcodes
			case 0xA9: //LDA #oper
				update_NZ(cpu6502.regA = cache_read_byte(cpu6502.regPC++));
				COUNT(2);
				break;
			case 0xA5: //LDA $zp
				update_NZ(cpu6502.regA = cache_read_byte(cache_read_byte(cpu6502.regPC++)));
				COUNT(3);
				break;
			case 0xB5: //LDA zp,X
				update_NZ(cpu6502.regA = cache_read_byte((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF));
				COUNT(4);
				break;
			case 0xAD: //LDA $oper
				update_NZ(cpu6502.regA = cache_read_byte(cache_read_word(cpu6502.regPC)));
				cpu6502.regPC += 2;
				COUNT(4);
				break;
			case 0xBD: //LDA $oper,X
				update_NZ(cpu6502.regA = cache_read_byte(X = (Y = cache_read_word(cpu6502.regPC)) + cpu6502.regX));
				cpu6502.regPC += 2;
				if ((X ^ Y) & 0xFF00) {
					COUNT(5);
				} else {
					COUNT(4);
				}
				break;
			case 0xB9: //LDA $oper,Y
				update_NZ(cpu6502.regA = cache_read_byte(X = (Y = cache_read_word(cpu6502.regPC)) + cpu6502.regY));
				cpu6502.regPC += 2;
				if ((X ^ Y) & 0xFF00) {
					COUNT(5);
				} else {
					COUNT(4);
				}
				break;
			case 0xA1: // LDA ($oper,X)
				update_NZ(cpu6502.regA = cache_read_byte(cache_read_word((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF)));
				COUNT(6);
				break;
			case 0xB1: // LDA ($oper),Y
				update_NZ(cpu6502.regA = cache_read_byte(X = (Y = cache_read_word(cache_read_byte(cpu6502.regPC++))) + cpu6502.regY));
				if ((X ^ Y) & 0xFF00) {
					COUNT(6);
				} else {
					COUNT(5);
				}
				break;

			// LDX opcodes
			case 0xA2: //LDX #oper
				update_NZ(cpu6502.regX = cache_read_byte(cpu6502.regPC++));
				COUNT(2);
				break;
			case 0xA6: //LDX $zp
				update_NZ(cpu6502.regX = cache_read_byte(cache_read_byte(cpu6502.regPC++)));
				COUNT(3);
				break;
			case 0xB6: //LDX zp,Y
				update_NZ(cpu6502.regX = cache_read_byte((cache_read_byte(cpu6502.regPC++) + cpu6502.regY) & 0xFF));
				COUNT(4);
				break;
			case 0xAE: //LDX $oper
				update_NZ(cpu6502.regX = cache_read_byte(cache_read_word(cpu6502.regPC)));
				cpu6502.regPC += 2;
				COUNT(4);
				break;
			case 0xBE: //LDX $oper,Y
				update_NZ(cpu6502.regX = cache_read_byte(X = (Y = cache_read_word(cpu6502.regPC)) + cpu6502.regY));
				cpu6502.regPC += 2;
				if ((X ^ Y) & 0xFF00) {
					COUNT(5);
				} else {
					COUNT(4);
				}
				break;

			// LDY opcodes
			case 0xA0: //LDY #oper
				update_NZ(cpu6502.regY = cache_read_byte(cpu6502.regPC++));
				COUNT(2);
				break;
			case 0xA4: //LDY $zp
				update_NZ(cpu6502.regY = cache_read_byte(cache_read_byte(cpu6502.regPC++)));
				COUNT(3);
				break;
			case 0xB4: //LDY zp,X
				update_NZ(cpu6502.regY = cache_read_byte((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF));
				COUNT(4);
				break;
			case 0xAC: //LDY $oper
				update_NZ(cpu6502.regY = cache_read_byte(cache_read_word(cpu6502.regPC)));
				cpu6502.regPC += 2;
				COUNT(4);
				break;
			case 0xBC: //LDY $oper,X
				update_NZ(cpu6502.regY = cache_read_byte(X = (Y = cache_read_word(cpu6502.regPC)) + cpu6502.regX));
				cpu6502.regPC += 2;
				if ((X ^ Y) & 0xFF00) {
					COUNT(5);
				} else {
					COUNT(4);
				}
				break;

			// LSR opcodes
			case 0x4A: //LSR A
				res = cpu6502.regA;
				val1 = res >> 1;
				res = val1 | ((res << 8) & 0x100);
				cpu6502.regA = val1;
				update_NZC(res);
				COUNT(2);
				break;
			case 0x46: //LSR $zp
				res = cache_read_byte(addr = cache_read_byte(cpu6502.regPC++));
				val1 = res >> 1;
				res = val1 | ((res << 8) & 0x100);
				cache_write_byte(addr, val1);
				update_NZC(res);
				COUNT(5);
				break;
			case 0x56: //LSR zp,X
				res = cache_read_byte(addr = ((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF));
				val1 = res >> 1;
				res = val1 | ((res << 8) & 0x100);
				cache_write_byte(addr, val1);
				update_NZC(res);
				COUNT(6);
				break;
			case 0x4E: //LSR $oper
				res = cache_read_byte(addr = cache_read_word(cpu6502.regPC));
				cpu6502.regPC += 2;
				val1 = res >> 1;
				res = val1 | ((res << 8) & 0x100);
				cache_write_byte(addr, val1);
				update_NZC(res);
				COUNT(6);
				break;
			case 0x5E: //LSR $oper,X
				res = cache_read_byte(addr = cache_read_word(cpu6502.regPC) + cpu6502.regX);
				cpu6502.regPC += 2;
				val1 = res >> 1;
				res = val1 | ((res << 8) & 0x100);
				cache_write_byte(addr, val1);
				update_NZC(res);
				COUNT(7);
				break;

			case 0xEA: // NOP
				COUNT(2);
				break;

			// ORA
			case 0x09: // ORA #oper
				update_NZ(cpu6502.regA |= cache_read_byte(cpu6502.regPC++));
				COUNT(2);
				break;
			case 0x05: // ORA $zp
				update_NZ(cpu6502.regA |= cache_read_byte(cache_read_byte(cpu6502.regPC++)));
				COUNT(3);
				break;
			case 0x15: // ORA zp,X
				update_NZ(cpu6502.regA |= cache_read_byte((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF));
				COUNT(4);
				break;
			case 0x0D: // ORA $oper
				update_NZ(cpu6502.regA |= cache_read_byte(cache_read_word(cpu6502.regPC)));
				cpu6502.regPC += 2;
				COUNT(4);
				break;
			case 0x1D: // ORA $oper,X
				update_NZ(cpu6502.regA |= cache_read_byte(X = (Y = cache_read_word(cpu6502.regPC)) + cpu6502.regX));
				cpu6502.regPC += 2;
				if ((X ^ Y) & 0xFF00) {
					COUNT(5);
				} else {
					COUNT(4);
				}
				break;
			case 0x19: // ORA $oper,Y
				update_NZ(cpu6502.regA |= cache_read_byte(X = (Y = cache_read_word(cpu6502.regPC)) + cpu6502.regY));
				cpu6502.regPC += 2;
				if ((X ^ Y) & 0xFF00) {
					COUNT(5);
				} else {
					COUNT(4);
				}
				break;
			case 0x01: // ORA ($oper,X)
				update_NZ(cpu6502.regA |= cache_read_byte(cache_read_word((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF)));
				COUNT(6);
				break;
			case 0x11: // ORA ($oper),Y
				update_NZ(cpu6502.regA |= cache_read_byte(X = (Y = cache_read_word(cache_read_byte(cpu6502.regPC++))) + cpu6502.regY));
				if ((X ^ Y) & 0xFF00) {
					COUNT(6);
				} else {
					COUNT(5);
				}
				break;

			case 0x48: // PHA
				cache_write_byte(0x100 + (cpu6502.regSP-- & 0xFF), cpu6502.regA);
				COUNT(3);
				break;
			case 0x08: // PHP
				cache_write_byte(0x100 + (cpu6502.regSP-- & 0xFF), cpu6502.regSR | FLAGS_B);
				COUNT(3);
				break;
			case 0x68: // PLA
				cpu6502.regA = cache_read_byte(0x100 + (++cpu6502.regSP & 0xFF));
				update_NZ(cpu6502.regA);
				COUNT(4);
				break;
			case 0x28: // PLP
				cpu6502.regSR = cache_read_byte(0x100 + (++cpu6502.regSP & 0xFF)) & ~FLAGS_B;
				COUNT(4);
				break;

			// ROL opcodes
			case 0x2A: //ROL A
				res = cpu6502.regA;
				res = (res << 1) | (cpu6502.regSR & FLAGS_C);
				cpu6502.regA = res;
				update_NZC(res);
				COUNT(2);
				break;
			case 0x26: //ROL $zp
				res = cache_read_byte(addr = cache_read_byte(cpu6502.regPC++));
				res = (res << 1) | (cpu6502.regSR & FLAGS_C);
				cache_write_byte(addr, res);
				update_NZC(res);
				COUNT(5);
				break;
			case 0x36: //ROL zp,X
				res = cache_read_byte(addr = ((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF));
				res = (res << 1) | (cpu6502.regSR & FLAGS_C);
				cache_write_byte(addr, res);
				update_NZC(res);
				COUNT(6);
				break;
			case 0x2E: //ROL $oper
				res = cache_read_byte(addr = cache_read_word(cpu6502.regPC));
				cpu6502.regPC += 2;
				res = (res << 1) | (cpu6502.regSR & FLAGS_C);
				cache_write_byte(addr, res);
				update_NZC(res);
				COUNT(6);
				break;
			case 0x3E: //ROL $oper,X
				res = cache_read_byte(addr = cache_read_word(cpu6502.regPC) + cpu6502.regX);
				cpu6502.regPC += 2;
				res = (res << 1) | (cpu6502.regSR & FLAGS_C);
				cache_write_byte(addr, res);
				update_NZC(res);
				COUNT(7);
				break;

			// ROR opcodes
			case 0x6A: //ROR A
				res = cpu6502.regA;
				val1 = (res >> 1) | (((uint16_t)cpu6502.regSR & FLAGS_C) << 7);
				cpu6502.regA = val1;
				update_NZC(val1 | ((res & 1) << 8));
				COUNT(2);
				break;
			case 0x66: //ROR $zp
				res = cache_read_byte(addr = cache_read_byte(cpu6502.regPC++));
				val1 = (res >> 1) | (((uint16_t)cpu6502.regSR & FLAGS_C) << 7);
				cache_write_byte(addr, val1);
				update_NZC(val1 | ((res & 1) << 8));
				COUNT(5);
				break;
			case 0x76: //ROR zp,X
				res = cache_read_byte(addr = ((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF));
				val1 = (res >> 1) | (((uint16_t)cpu6502.regSR & FLAGS_C) << 7);
				cache_write_byte(addr, val1);
				update_NZC(val1 | ((res & 1) << 8));
				COUNT(6);
				break;
			case 0x6E: //ROR $oper
				res = cache_read_byte(addr = cache_read_word(cpu6502.regPC));
				cpu6502.regPC += 2;
				val1 = (res >> 1) | (((uint16_t)cpu6502.regSR & FLAGS_C) << 7);
				cache_write_byte(addr, val1);
				update_NZC(val1 | ((res & 1) << 8));
				COUNT(6);
				break;
			case 0x7E: //ROR $oper,X
				res = cache_read_byte(addr = cache_read_word(cpu6502.regPC) + cpu6502.regX);
				cpu6502.regPC += 2;
				val1 = (res >> 1) | (((uint16_t)cpu6502.regSR & FLAGS_C) << 7);
				cache_write_byte(addr, val1);
				update_NZC(val1 | ((res & 1) << 8));
				COUNT(7);
				break;

			case 0x40: // RTI
				cpu6502.regSR = cache_read_byte(0x100 + (++cpu6502.regSP));
				res = cache_read_byte(0x100 + (++cpu6502.regSP));
				res |= (uint16_t)cache_read_byte(0x100 + (++cpu6502.regSP)) << 8;
				cpu6502.regPC = res;
				COUNT(6);
				break;
			case 0x60: // RTS
				// Pull LO then HI
				res = cache_read_byte(0x100 + (++cpu6502.regSP & 0xFF));
				res |= (uint16_t)cache_read_byte(0x100 + (++cpu6502.regSP & 0xFF)) << 8;
				cpu6502.regPC = res + 1; // RTS always adds 1 to the pulled address
				COUNT(6);
				break;

			// SBC opcodes
			case 0xE9: // SBC #oper
				val2 = cache_read_byte(cpu6502.regPC++);
				do_sbc(val1, val2);
				COUNT(2);
				break;
			case 0xE5: // SBC $zp
				val2 = cache_read_byte(cache_read_byte(cpu6502.regPC++));
				do_sbc(val1, val2);
				COUNT(3);
				break;
			case 0xF5: // SBC zp,X
				val2 = cache_read_byte((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF);
				do_sbc(val1, val2);
				COUNT(4);
				break;
			case 0xED: // SBC $oper
				val2 = cache_read_byte(cache_read_word(cpu6502.regPC));
				cpu6502.regPC += 2;
				do_sbc(val1, val2);
				COUNT(4);
				break;
			case 0xFD: // SBC $oper,X
				val2 = cache_read_byte(X = (Y = cache_read_word(cpu6502.regPC)) + cpu6502.regX);
				cpu6502.regPC += 2;
				do_sbc(val1, val2);
				if ((X ^ Y) & 0xFF00) {
					COUNT(5);
				} else {
					COUNT(4);
				}
				break;
			case 0xF9: // SBC $oper,Y
				val2 = cache_read_byte(X = (Y = cache_read_word(cpu6502.regPC)) + cpu6502.regY);
				cpu6502.regPC += 2;
				do_sbc(val1, val2);
				if ((X ^ Y) & 0xFF00) {
					COUNT(5);
				} else {
					COUNT(4);
				}
				break;
			case 0xE1: // SBC ($oper,X)
				val2 = cache_read_byte(cache_read_word((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF));
				do_sbc(val1, val2);
				COUNT(6);
				break;
			case 0xF1: // SBC ($oper),Y
				val2 = cache_read_byte(X = (Y = cache_read_word(cache_read_byte(cpu6502.regPC++))) + cpu6502.regY);
				do_sbc(val1, val2);
				if ((X ^ Y) & 0xFF00) {
					COUNT(6);
				} else {
					COUNT(5);
				}
				break;

			case 0x38: // SEC
				cpu6502.regSR |= FLAGS_C;
				COUNT(2);
				break;
			case 0xF8: // SED
				cpu6502.regSR |= FLAGS_D;
				COUNT(2);
				break;
			case 0x78: // SEI
				cpu6502.regSR |= FLAGS_I;
				COUNT(2);
				break;

			// STA opcodes
			case 0x85: //STA $zp
				cache_write_byte(cache_read_byte(cpu6502.regPC++), cpu6502.regA);
				COUNT(3);
				break;
			case 0x95: //STA zp,X
				cache_write_byte((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF, cpu6502.regA);
				COUNT(4);
				break;
			case 0x8D: //STA $oper
				cache_write_byte(cache_read_word(cpu6502.regPC), cpu6502.regA);
				cpu6502.regPC += 2;
				COUNT(4);
				break;
			case 0x9D: //STA $oper,X
				cache_write_byte(cache_read_word(cpu6502.regPC) + cpu6502.regX, cpu6502.regA);
				cpu6502.regPC += 2;
				COUNT(5);
				break;
			case 0x99: //STA $oper,Y
				cache_write_byte(cache_read_word(cpu6502.regPC) + cpu6502.regY, cpu6502.regA);
				cpu6502.regPC += 2;
				COUNT(5);
				break;
			case 0x81: // STA ($oper,X)
				cache_write_byte(cache_read_word((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF), cpu6502.regA);
				COUNT(6);
				break;
			case 0x91: // STA ($oper),Y
				cache_write_byte(cache_read_word(cache_read_byte(cpu6502.regPC++)) + cpu6502.regY, cpu6502.regA);
				COUNT(6);
				break;

			// STX
			case 0x86: //STX $zp
				cache_write_byte(cache_read_byte(cpu6502.regPC++), cpu6502.regX);
				COUNT(3);
				break;
			case 0x96: //STX $zp,Y
				cache_write_byte((cache_read_byte(cpu6502.regPC++) + cpu6502.regY) & 0xFF, cpu6502.regX);
				COUNT(4);
				break;
			case 0x8E: //STX $oper
				cache_write_byte(cache_read_word(cpu6502.regPC), cpu6502.regX);
				cpu6502.regPC += 2;
				COUNT(4);
				break;

			// STY
			case 0x84: //STY $zp
				cache_write_byte(cache_read_byte(cpu6502.regPC++), cpu6502.regY);
				COUNT(3);
				break;
			case 0x94: //STY $zp,X
				cache_write_byte((cache_read_byte(cpu6502.regPC++) + cpu6502.regX) & 0xFF, cpu6502.regY);
				COUNT(4);
				break;
			case 0x8C: //STY $oper
				cache_write_byte(cache_read_word(cpu6502.regPC), cpu6502.regY);
				cpu6502.regPC += 2;
				COUNT(4);
				break;

			case 0xAA: // TAX
				update_NZ(cpu6502.regX = cpu6502.regA);
				COUNT(2);
				break;
			case 0xA8: // TAY
				update_NZ(cpu6502.regY = cpu6502.regA);
				COUNT(2);
				break;
			case 0xBA: // TSX	
				update_NZ(cpu6502.regX = cpu6502.regSP);
				COUNT(2);
				break;
			case 0x8A: // TXA
				update_NZ(cpu6502.regA = cpu6502.regX);
				COUNT(2);
				break;
			case 0x9A: // TXS (nf)
				cpu6502.regSP = cpu6502.regX;
				COUNT(2);
				break;
			case 0x98: // TYA
				update_NZ(cpu6502.regA = cpu6502.regY);
				COUNT(2);
				break;
		}
	}
}

#endif
