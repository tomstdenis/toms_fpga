#ifdef CPU_RISCV32IM

static struct {
	uint32_t regPC, r[32];
} cpu;

#if defined(TRACE) && defined(HOSTPC)
#include <ncurses.h>
#define LOG(...) fprintf(stderr, __VA_ARGS__) 
#else
#define LOG(...)
#endif


#ifdef TRACE
void trace_riscv()
{
	LOG("CPU: {pc=0x%lx,sp=0x%lx,s0=0x%lx", (unsigned long)cpu.regPC, (unsigned long)cpu.r[2], (unsigned long)cpu.r[8]);
	refresh();
}
#endif

void init_riscv()
{
	memset(&cpu, 0, sizeof cpu);
	cpu.regPC = SPI_SRAM_TOP; // start at the beginning of flash
}

void int_riscv(uint8_t sig)
{
}

static void step_32(uint32_t inst)
{
	uint8_t op, rd, rs1, rs2, funct3, funct7;
	uint32_t res;

	// parse out the fields
	op = inst & 0x7F;
	rd = (inst >> 7) & 0x1F;
	funct3 = (inst >> 12) & 0x07;
	rs1 = (inst >> 15) & 0x1F;
	rs2 = (inst >> 20) & 0x1F;
	funct7 = (inst >> 25);

#ifdef TRACE
	LOG("op=%lx, %lx, %lx, %lx, %lx, funct7=%lx, ", (unsigned long)op, (unsigned long)rd, (unsigned long)funct3, (unsigned long)rs1, (unsigned long)rs2, (unsigned long)funct7);
#endif

	// run opcodes
	switch (op) {
		case 3: { // load
			uint32_t imm = ((int32_t)inst) >> 20; // sign extend immediate
			switch (funct3) {
				case 0: // load byte
					res = cache_read_byte(cpu.r[rs1] + imm);
					res = (res ^ 0x80) - 0x80; // sign extend result
					break;
				case 1: // load half
					res = cache_read_word(cpu.r[rs1] + imm);
					res = (res ^ 0x8000) - 0x8000;
					break;
				case 2: // load dword
					res = cache_read_word(cpu.r[rs1] + imm) | ((uint32_t)cache_read_word(cpu.r[rs1] + imm + 2) << 16);
					break;
				case 4: // load byte (U)
					res = cache_read_byte(cpu.r[rs1] + imm);
					break;
				case 5: // load half (U)
					res = cache_read_word(cpu.r[rs1] + imm);
					break;
			}
			cpu.r[rd] = res;
			break;
		}
		case 0x13: { // OP-IMM
			int32_t imm = ((int32_t)inst) >> 20;
			switch (funct3) {
				case 0: // ADDI
					res = cpu.r[rs1] + imm;
					break;
				case 1: // SLLI
					res = cpu.r[rs1] << (imm & 0x1F);
					break;
				case 2: // SLTI (Set Less Than Immediate)
					res = ((int32_t)cpu.r[rs1] < imm) ? 1 : 0;
					break;
				case 3: // SLTIU (unsigned)
					res = cpu.r[rs1] < (uint32_t)imm ? 1 : 0;
					break;
				case 4: // XORI
					res = cpu.r[rs1] ^ imm;
					break;
				case 5: // srli/srai
					if (funct7 & 0x20) { // Bit 30 is set
							res = (int32_t)cpu.r[rs1] >> (imm & 0x1F);
					} else {
						res = cpu.r[rs1] >> (imm & 0x1F);
					}
					break;
				case 6: // ORI
					res = cpu.r[rs1] | imm;
					break;
				case 7: // ANDI
					res = cpu.r[rs1] & imm;
					break;
			}
			cpu.r[rd] = res;
			break;
		}
		case 0x23: { // Store Instructions
			// Reconstruct the 12-bit signed immediate for S-type
			// bits 31:25 are high part, bits 11:7 are low part
			int32_t imm = (int32_t)((inst & 0xFE000000) | ((inst & 0x00000F80) << 13)) >> 20;

			uint32_t addr = cpu.r[rs1] + imm;
			uint32_t val  = cpu.r[rs2];

			switch (funct3) {
				case 0: // SB (Store Byte)
					cache_write_byte(addr, (uint8_t)val);
					break;
				case 1: // SH (Store Half)
					// Since your cache writes 16-bit 'words':
					cache_write_word(addr, (uint16_t)val);
					break;
				case 2: // SW (Store Word)
					// Two 16-bit writes for a 32-bit RISC-V word
					cache_write_word(addr, (uint16_t)val);
					cache_write_word(addr + 2, (uint16_t)(val >> 16));
					break;
			}
			break;
		}
		case 0x33: { // R-type ALU opcodes
			if (funct7 == 0x01) { // M-Extension
				switch (funct3) {
					case 0: res = (uint32_t)((int32_t)cpu.r[rs1] * (int32_t)cpu.r[rs2]); break;
					case 1: res = (uint32_t)(((int64_t)(int32_t)cpu.r[rs1] * (int64_t)(int32_t)cpu.r[rs2]) >> 32); break;
					case 2: res = (uint32_t)(((int64_t)(int32_t)cpu.r[rs1] * (uint64_t)cpu.r[rs2]) >> 32); break;
					case 3: res = (uint32_t)(((uint64_t)cpu.r[rs1] * (uint64_t)cpu.r[rs2]) >> 32); break;
					case 4: // DIV
						if (cpu.r[rs2] == 0) res = -1;
						else if ((int32_t)cpu.r[rs1] == INT32_MIN && (int32_t)cpu.r[rs2] == -1) res = INT32_MIN;
						else res = (int32_t)cpu.r[rs1] / (int32_t)cpu.r[rs2];
						break;
					case 5: // DIVU
						if (cpu.r[rs2] == 0) res = 0xFFFFFFFF;
						else res = cpu.r[rs1] / cpu.r[rs2];
						break;
					case 6: // REM
						if (cpu.r[rs2] == 0) res = cpu.r[rs1];
						else if ((int32_t)cpu.r[rs1] == INT32_MIN && (int32_t)cpu.r[rs2] == -1) res = 0;
						else res = (int32_t)cpu.r[rs1] % (int32_t)cpu.r[rs2];
						break;
					case 7: // REMU
						if (cpu.r[rs2] == 0) res = cpu.r[rs1];
						else res = cpu.r[rs1] % cpu.r[rs2];
						break;
				}
			} else {
				switch (funct3) {
					case 0: // add/sub
						if (funct7 == 0x20) {
							res = cpu.r[rs1] - cpu.r[rs2];
						} else {
							res = cpu.r[rs1] + cpu.r[rs2];
						}
						break;
					case 1: // shift logical left
						res = cpu.r[rs1] << (cpu.r[rs2] & 0x1F);
						break;
					case 2: // set less than signed
						res = ((int32_t)cpu.r[rs1] < (int32_t)cpu.r[rs2]) ? 1 : 0;
						break;
					case 3: // set less than unsigned
						res = (cpu.r[rs1] < cpu.r[rs2]) ? 1 : 0;
						break;
					case 4: // xor
						res = cpu.r[rs1] ^ cpu.r[rs2];
						break;
					case 5: // shift logical right
						if (funct7 == 0x20) {
							res = ((int32_t)cpu.r[rs1]) >> (cpu.r[rs2] & 0x1F);
						} else {
							res = cpu.r[rs1] >> (cpu.r[rs2] & 0x1F);
						}
						break;
					case 6: // or
						res = cpu.r[rs1] | cpu.r[rs2];
						break;
					case 7: // and
						res = cpu.r[rs1] & cpu.r[rs2];
						break;
				}
			}
			cpu.r[rd] = res;
			break;
		}
		case 0x63: { // Branch Instructions
			// 1. Unscramble the B-type immediate
			int32_t imm = (int32_t)((inst & 0x80000000) >> 19) | // bit 12 (sign)
						  ((inst & 0x00000080) << 4)  | // bit 11
						  ((inst & 0x7E000000) >> 20) | // bits 10:5
						  ((inst & 0x00000F00) >> 7);   // bits 4:1
			
			// Sign extend from bit 12
			if (imm & 0x1000) imm |= 0xFFFFE000;

			// 2. Evaluate the branch condition
			bool take = false;
			uint32_t src1 = cpu.r[rs1];
			uint32_t src2 = cpu.r[rs2];

			switch (funct3) {
				case 0: take = (src1 == src2); break;            // BEQ
				case 1: take = (src1 != src2); break;            // BNE
				case 4: take = ((int32_t)src1 < (int32_t)src2); break; // BLT
				case 5: take = ((int32_t)src1 >= (int32_t)src2); break; // BGE
				case 6: take = (src1 < src2); break;             // BLTU
				case 7: take = (src1 >= src2); break;            // BGEU
			}

			// 3. Update PC
			if (take) {
				// Since your step_riscv already added 4 to PC, we subtract 4 
				// then add the branch offset to get back to the right spot.
				cpu.regPC = (cpu.regPC - 4) + imm;
			}
			break;
		}

		case 0x37: // LUI (Load Upper Immediate)
			cpu.r[rd] = inst & 0xFFFFF000;
			break;

		case 0x17: // AUIPC (Add Upper Immediate to PC)
			// Add to the address of THIS instruction (PC-4 because it's already incremented)
			cpu.r[rd] = (cpu.regPC - 4) + (inst & 0xFFFFF000);
			break;

		case 0x6F: { // JAL (Jump and Link)
			// Save return address (address of NEXT instruction)
			cpu.r[rd] = cpu.regPC; 

			// Unscramble J-type immediate (20-bit signed, shifted left 1)
			int32_t imm = (int32_t)((inst & 0x80000000) >> 11) | // bit 20 (sign)
						  (inst & 0x000FF000) |                 // bits 19:12
						  ((inst & 0x00100000) >> 9) |          // bit 11
						  ((inst & 0x7FE00000) >> 20);          // bits 10:1
			
			// Sign extend from bit 20 to 32
			if (imm & 0x100000) imm |= 0xFFE00000;

			// Jump relative to the start of this instruction
			cpu.regPC = (cpu.regPC - 4) + imm;
			break;
		}

		case 0x67: { // JALR (Jump and Link Register)
			uint32_t next_pc = cpu.regPC; // Return address
			int32_t imm = ((int32_t)inst) >> 20; // I-type sign extension
			
			// Target is (rs1 + imm) with the least-significant bit forced to 0
			cpu.regPC = (cpu.r[rs1] + imm) & ~1;
			cpu.r[rd] = next_pc;
			break;
		}				
	}
	cpu.r[0] = 0; // always force x0 to zero
}

#ifdef TRACE
//LOG("op=%lx, inst=%lx, ", (unsigned long)op, (unsigned long)inst);
#endif

static void step_16(uint16_t inst) {
    uint16_t u_inst = (uint32_t)inst;
    uint8_t op = u_inst & 0x03;
    uint8_t funct3 = (u_inst >> 13) & 0x07;

#ifdef TRACE
    LOG("op=%lx, inst=%lx, ", (unsigned long)op, (unsigned long)inst);
#endif

    // RVC Register Mapping:
    // compressed instructions often access x8-x15 (s0-s1, a0-a5)
    // using a 3-bit index.
    #define R_P(i) (8 + (i)) 

    switch (op) {
        // ============================================================
        // Quadrant 0
        // ============================================================
        case 0: 
            if (funct3 == 0) { // c.addi4spn (Add Immediate to SP, Nondestructive)
                // Format: CIW. exp: imm[5:4|9:6|2|3]
                uint32_t imm = 
                    ((u_inst >> 7) & 0x30)  | // inst[12:11] -> imm[5:4]
                    ((u_inst >> 1) & 0x3C0) | // inst[10:7]  -> imm[9:6]
                    ((u_inst >> 4) & 0x04)  | // inst[6]     -> imm[2]
                    ((u_inst >> 2) & 0x08);   // inst[5]     -> imm[3]
                
                if (imm != 0) {
                    cpu.r[R_P((u_inst >> 2) & 7)] = cpu.r[2] + imm; 
                }
            } 
            else if (funct3 == 2) { // c.lw (Load Word)
                // Format: CL. exp: imm[5:3|2|6]
                uint32_t imm = 
                    (((u_inst >> 6)  & 1) << 2) | 
                    (((u_inst >> 10) & 7) << 3) | 
                    (((u_inst >> 5)  & 1) << 6);
                
                uint32_t addr = cpu.r[R_P((u_inst >> 7) & 7)] + imm;
                // Little-endian load (combine two 16-bit reads)
                cpu.r[R_P((u_inst >> 2) & 7)] = (uint16_t)cache_read_word(addr) | 
                                               ((uint32_t)cache_read_word(addr + 2) << 16);
            } 
            else if (funct3 == 6) { // c.sw (Store Word)
                // Format: CS. exp: imm[5:3|2|6]
                uint32_t imm = 
                    (((u_inst >> 6)  & 1) << 2) | 
                    (((u_inst >> 10) & 7) << 3) | 
                    (((u_inst >> 5)  & 1) << 6);

                uint32_t addr = cpu.r[R_P((u_inst >> 7) & 7)] + imm;
                uint32_t val  = cpu.r[R_P((u_inst >> 2) & 7)];
                
                // Little-endian store
                cache_write_word(addr, (uint16_t)val); 
                cache_write_word(addr + 2, (uint16_t)(val >> 16));
            }
            break;

        // ============================================================
        // Quadrant 1
        // ============================================================
        case 1: 
            if (funct3 == 0 || funct3 == 2) { // c.addi (0), c.li (2)
                int32_t imm = ((u_inst >> 2) & 0x1F);
                if (u_inst & (1 << 12)) imm |= 0xFFFFFFE0; // Sign extend 6-bit

                uint8_t rd = (u_inst >> 7) & 0x1F;
                if (rd != 0) {
                    // c.addi adds to rd; c.li loads const into rd (rd=0 implies x0, treated as 0)
                    cpu.r[rd] = (funct3 == 0) ? (uint32_t)((int32_t)cpu.r[rd] + imm) : (uint32_t)imm;
                }
            } 
            else if (funct3 == 1 || funct3 == 5) { // c.jal (1) / c.j (5)
                // Format: CJ. exp: imm[11|4|9:8|10|6|7|3:1|5]
                int32_t imm = 
                    (((u_inst >> 3)  & 0x7) << 1)  | 
                    (((u_inst >> 11) & 0x1) << 4)  | 
                    (((u_inst >> 2)  & 0x1) << 5)  | 
                    (((u_inst >> 7)  & 0x1) << 6)  | 
                    (((u_inst >> 6)  & 0x1) << 7)  | 
                    (((u_inst >> 9)  & 0x3) << 8)  | 
                    (((u_inst >> 8)  & 0x1) << 10) | 
                    (((u_inst >> 12) & 0x1) << 11);
                
                if (imm & 0x800) imm |= 0xFFFFF000; // Sign extend 12-bit

                if (funct3 == 1) cpu.r[1] = cpu.regPC; // c.jal links return address to RA
                cpu.regPC = (cpu.regPC - 2) + imm;     // Jump (PC is already advanced by 2 in main loop)
            } 
            else if (funct3 == 3) { // c.lui / c.addi16sp
                uint8_t rd = (u_inst >> 7) & 0x1F;
                
                if (rd == 2) { // c.addi16sp (Add Immediate to SP, 16-byte aligned)
                    // Format: imm[9|4|6|8:7|5] -> scaled by 16
                    int32_t imm = 
                        (((u_inst >> 12) & 1) << 9) | 
                        (((u_inst >> 3)  & 3) << 7) | 
                        (((u_inst >> 5)  & 1) << 6) | 
                        (((u_inst >> 2)  & 1) << 5) | 
                        (((u_inst >> 6)  & 1) << 4);
                    
                    if (imm & 0x200) imm |= 0xFFFFFC00; // Sign extend
                    cpu.r[2] = (uint32_t)((int32_t)cpu.r[2] + imm);
                } 
                else if (rd != 0) { // c.lui (Load Upper Immediate)
                    // Format: imm[17|16:12]
                    int32_t imm = ((int32_t)(u_inst >> 12) & 1) << 17 | ((int32_t)(u_inst >> 2) & 0x1F) << 12;
                    if (imm & 0x20000) imm |= 0xFFFC0000; // Sign extend
                    cpu.r[rd] = imm;
                }
            } 
            else if (funct3 == 4) { // ALU Arithmetic (sub, xor, or, and) & Shift (srli, srai, andi)
                uint8_t rd_p = R_P((u_inst >> 7) & 7);
                uint8_t sel  = (u_inst >> 10) & 3;

                if (sel < 3) { // Immediate ops: c.srli, c.srai, c.andi
                    uint32_t imm = ((u_inst >> 2) & 0x1F) | ((u_inst >> 7) & 0x20); // imm[5] | imm[4:0]
                    
                    if (sel == 0)      cpu.r[rd_p] >>= (imm & 0x1F);                            // c.srli
                    else if (sel == 1) cpu.r[rd_p] = (uint32_t)((int32_t)cpu.r[rd_p] >> (imm & 0x1F)); // c.srai
                    else               cpu.r[rd_p] &= (imm | ((imm & 0x20) ? 0xFFFFFFC0 : 0));  // c.andi
                } 
                else { // Register ops: c.sub, c.xor, c.or, c.and
                    uint8_t rs2_p   = R_P((u_inst >> 2) & 7);
                    uint8_t sub_sel = (u_inst >> 5) & 3;

                    if (sub_sel == 0)      cpu.r[rd_p] -= cpu.r[rs2_p]; // c.sub
                    else if (sub_sel == 1) cpu.r[rd_p] ^= cpu.r[rs2_p]; // c.xor
                    else if (sub_sel == 2) cpu.r[rd_p] |= cpu.r[rs2_p]; // c.or
                    else                   cpu.r[rd_p] &= cpu.r[rs2_p]; // c.and
                }
            } 
            else if (funct3 == 6 || funct3 == 7) { // c.beqz (6), c.bnez (7)
                // Format: CB. exp: imm[8|4:3|7:6|2:1|5]
                int32_t imm = 
                    (((u_inst >> 12) & 1) << 8) | 
                    (((u_inst >> 5)  & 3) << 6) | 
                    (((u_inst >> 2)  & 1) << 5) | 
                    (((u_inst >> 10) & 3) << 3) | 
                    (((u_inst >> 3)  & 3) << 1);
                
                if (imm & 0x100) imm |= 0xFFFFFE00; // Sign extend

                uint32_t val = cpu.r[R_P((u_inst >> 7) & 7)];
                if ((funct3 == 6 && val == 0) || (funct3 == 7 && val != 0)) {
                    cpu.regPC = (cpu.regPC - 2) + imm;
                }
            }
            break;

        // ============================================================
        // Quadrant 2
        // ============================================================
        case 2: 
            if (funct3 == 0) { // c.slli (Shift Left Logical Immediate)
                uint8_t rd = (u_inst >> 7) & 0x1F;
                if (rd != 0) {
                    cpu.r[rd] <<= (((u_inst >> 2) & 0x1F) | ((u_inst >> 7) & 0x20));
                }
            } 
            else if (funct3 == 2) { // c.lwsp (Load Word from Stack Pointer)
                // Format: CSS. exp: imm[5|4:2|7:6]
                uint32_t imm =
                    (((u_inst >> 4)  & 0x7) << 2) | // inst[6:4] -> imm[4:2]
                    (((u_inst >> 12) & 0x1) << 5) | // inst[12]  -> imm[5]
                    (((u_inst >> 2)  & 0x3) << 6);  // inst[3:2] -> imm[7:6]
   
                uint8_t rd = (u_inst >> 7) & 0x1F;
                if (rd != 0) {
                    uint32_t addr = cpu.r[2] + imm;
                    cpu.r[rd] = (uint16_t)cache_read_word(addr) |
                                ((uint32_t)cache_read_word(addr + 2) << 16);
                }
            } 
            else if (funct3 == 4) { // c.mv, c.add, c.jr, c.jalr
                uint8_t rd  = (u_inst >> 7) & 0x1F;
                uint8_t rs2 = (u_inst >> 2) & 0x1F;
                bool bit12  = (u_inst >> 12) & 1;

                if (!bit12) {
                    if (rs2 == 0)      cpu.regPC = cpu.r[rd] & ~1; // c.jr
                    else if (rd != 0)  cpu.r[rd] = cpu.r[rs2];     // c.mv
                } else {
                    if (rs2 == 0) { // c.jalr
                        uint32_t next = cpu.regPC; 
                        cpu.regPC = cpu.r[rd] & ~1; 
                        cpu.r[1]  = next;
                    } 
                    else if (rd != 0)  cpu.r[rd] += cpu.r[rs2];    // c.add
                }
            } 
            else if (funct3 == 6) { // c.swsp (Store Word to Stack Pointer)
                // Format: CSS. exp: imm[5:2|7:6]
                uint32_t imm =
                    (((u_inst >> 9) & 0xF) << 2) | // inst[12:9] -> imm[5:2]
                    (((u_inst >> 7) & 0x3) << 6);  // inst[8:7]  -> imm[7:6]

                uint32_t addr = cpu.r[2] + imm;
                uint32_t val  = cpu.r[(u_inst >> 2) & 0x1F]; // Source is rs2 (encoded in bits 6:2)
                
                cache_write_word(addr, (uint16_t)val);
                cache_write_word(addr + 2, (uint16_t)(val >> 16));
            }
            break;
    }
    
    cpu.r[0] = 0; // Guard: x0 is always 0
    #undef R_P
}

void step_riscv(uint16_t steps)
{
	uint32_t inst;

	while (steps--) {
		++cpu_cycles;
		// read first 16 bits to deterine if it's a compact or not
		inst = cache_read_word(cpu.regPC);
		cpu.regPC += 2;
		if ((inst & 3) == 3) {
			inst |= ((uint32_t)cache_read_word(cpu.regPC) << 16);
			cpu.regPC += 2;
			step_32(inst);
		} else {
			step_16(inst);
		}
	}
}

void reset_riscv(void)
{
	init_riscv();
}

void jump_riscv(cache_addr_t addr)
{
	cpu.regPC = addr;
}

uint16_t save_riscv(uint16_t offset)
{
	return offset;
}

uint16_t load_riscv(uint16_t offset)
{
	return offset;
}

#endif
