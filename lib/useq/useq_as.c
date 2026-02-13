#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <inttypes.h>

#define PROG_SIZE 4096

// the entire program can only be upto PROG_SIZE bytes so just make a simple map here
struct {
	uint8_t opcode;
	char label[64];
	char tgt[64];
	int use_top_half;
	int use_bottom_half;
	int line_number;
	int opidx;
	char line[512];
} program[PROG_SIZE];

struct {
	char label[64];
	uint8_t value;
} symbols[PROG_SIZE];

int line_number = 1;
uint16_t PC = 0;

/* bare bones assembler, allows whitespace and comments with ';'
 * 
 * a line starts with either ".ORG %x" to reset the orgiin or
 * ":%s" to denote a label or anything else to denote an instruction
 * 
 * There's three types of opcodes Xr where r is a 4-bit imm, 
 * or Xsb where s is a 3-bit imm and b is a 1-bit imm,
 * or XX where it's just a full byte with no operands
 */

#define E1_OP_FMT_R 0			// has an r
#define E1_OP_FMT_SB 1			// has an s, b
#define E1_OP_FMT_FULL 2		// no operands
#define E1_OP_FMT_IMM 3			// 8-bit immediate
#define E1_OP_FMT_IMM12 4		// 12-bit imm
#define E1_OP_FMT_IMMS 5		// 12-bit >> 4 => 8-bit

// EXEC1 instruction table
const struct {
	char *opname;
	uint8_t opcode;
	int fmt;
} e1_opcodes[] = {
	{ "LD", 0x00, E1_OP_FMT_R },
	{ "ST", 0x10, E1_OP_FMT_R },
	{ "SETB", 0x20, E1_OP_FMT_SB },
	{ "ADD", 0x30, E1_OP_FMT_R }, 
	{ "SUB", 0x40, E1_OP_FMT_R }, 
	{ "EOR", 0x50, E1_OP_FMT_R }, 
	{ "AND", 0x60, E1_OP_FMT_R }, 
	{ "OR" , 0x70, E1_OP_FMT_R }, 

	{ "LDI", 0x80, E1_OP_FMT_IMM },
	{ "ADDI", 0x81, E1_OP_FMT_IMM },
	{ "SUBI", 0x82, E1_OP_FMT_IMM },
	{ "EORI", 0x83, E1_OP_FMT_IMM },
	{ "ANDI", 0x84, E1_OP_FMT_IMM },
	{ "ORI", 0x85, E1_OP_FMT_IMM },
	{ "LDIR0", 0x86, E1_OP_FMT_IMM },
	{ "LDIR1", 0x87, E1_OP_FMT_IMM },
	{ "LDIR11", 0x88, E1_OP_FMT_IMM },
	{ "LDIR12", 0x89, E1_OP_FMT_IMM },
	{ "LDIR13", 0x8A, E1_OP_FMT_IMM },
	{ "LDIR14", 0x8B, E1_OP_FMT_IMM },
	{ "MUL", 0x8C, E1_OP_FMT_FULL },
	{ "LDM", 0x8D, E1_OP_FMT_FULL },
	{ "STM", 0x8E, E1_OP_FMT_FULL },
// 8E..8F
		
	{ "INC", 0x90, E1_OP_FMT_FULL },
	{ "DEC", 0x91, E1_OP_FMT_FULL },
	{ "ASL", 0x92, E1_OP_FMT_FULL },
	{ "LSR", 0x93, E1_OP_FMT_FULL },
	{ "ASR", 0x94, E1_OP_FMT_FULL },
	{ "SWAP", 0x95, E1_OP_FMT_FULL },
	{ "ROL", 0x96, E1_OP_FMT_FULL },
	{ "ROR", 0x97, E1_OP_FMT_FULL },
	{ "SWAPR0", 0x98, E1_OP_FMT_FULL },
	{ "SWAPR1", 0x99, E1_OP_FMT_FULL },
	{ "NOT", 0x9A, E1_OP_FMT_FULL },
	{ "CLR", 0x9B, E1_OP_FMT_FULL },
	{ "SIGT", 0x9C, E1_OP_FMT_FULL },
	{ "SIEQ", 0x9D, E1_OP_FMT_FULL },
	{ "SILT", 0x9E, E1_OP_FMT_FULL },
// 9F
	
	{ "JMP", 0xA0, E1_OP_FMT_IMM12 },
	{ "CALL", 0xB0, E1_OP_FMT_IMM12 },
	{ "JZ", 0xC0, E1_OP_FMT_IMM12 },
	{ "JNZ", 0xD0, E1_OP_FMT_IMM12 },

	{ "OUT", 0xE0, E1_OP_FMT_FULL },
	{ "OUTBIT", 0xE1, E1_OP_FMT_FULL },
	{ "TGLBIT", 0xE2, E1_OP_FMT_FULL },
	{ "IN", 0xE3, E1_OP_FMT_FULL },
	{ "INBIT", 0xE4, E1_OP_FMT_FULL },
	{ "NEG", 0xE5, E1_OP_FMT_FULL },
	{ "NOP", 0xE6, E1_OP_FMT_FULL },
	{ "SEI", 0xE7, E1_OP_FMT_IMM },
	{ "SAI", 0xE8, E1_OP_FMT_IMMS },
	{ "HLT", 0xE9, E1_OP_FMT_FULL },
	{ "RET", 0xEA, E1_OP_FMT_FULL },
	{ "RTI", 0xEB, E1_OP_FMT_FULL },
	{ "WAIT0", 0xEC, E1_OP_FMT_FULL },
	{ "WAIT1", 0xED, E1_OP_FMT_FULL },
	{ "WAITF", 0xEE, E1_OP_FMT_FULL },
	{ "WAITA", 0xEF, E1_OP_FMT_FULL },
	{ "SBIT", 0xF0, E1_OP_FMT_SB },
	{ NULL, 0x00, 0 },
};

int iswhitespace(char *s)
{
	return (*s == '\n' || *s == '\r' || *s == ' ' || *s == '\t');
}

void consume_whitespace(char **s)
{
	while (**s && iswhitespace(*s)) {
		++(*s);
	}
}

int islabel(char *s)
{
	return *s == '>' || *s == '<' || *s == '_' || isalpha(*s);
}

void consume_label(char *dest, char **s)
{
	while (isalnum(**s) || **s == '_') {
		*dest++ = *((*s)++);
	}
	*dest++ = 0;
}

void compile_exec1(char *line)
{
	int x;
	for (x = 0; e1_opcodes[x].opname; x++) {
		if (!memcmp(line, e1_opcodes[x].opname, strlen(e1_opcodes[x].opname)) && iswhitespace(&line[strlen(e1_opcodes[x].opname)])) {
			// matched an opcode
			line += strlen(e1_opcodes[x].opname);
			consume_whitespace(&line);
			program[PC].opcode = e1_opcodes[x].opcode;
			program[PC].opidx = x;
			if (program[PC].line_number == -1) {
				program[PC].line_number = line_number;
			} else {
				printf("line %d: byte location %x already was programmed on line %d\n", line_number, PC, program[PC].line_number);
				exit(-1);
			}
			switch (e1_opcodes[x].fmt) {
				case E1_OP_FMT_IMMS: // 12 => 8-bit imm
					program[PC+1].line_number = line_number;
					if (islabel(line)) {
						// it's a label
						if (*line == '<') {
							program[PC].use_top_half = 1;
							++line;
						} else if (*line == '>') {
							program[PC].use_bottom_half = 1;
							++line;
						}
						consume_label(program[PC].tgt, &line);
					} else {
						uint16_t r;
						// it's a value
						sscanf(line, "%"SCNx16, &r);
						program[PC+1].opcode = r >> 4;
					}
					++PC;
					break;

				case E1_OP_FMT_IMM12: // 12-bit imm
					program[PC+1].line_number = line_number;
					if (islabel(line)) {
						// it's a label
						if (*line == '<') {
							program[PC].use_top_half = 1;
							++line;
						} else if (*line == '>') {
							program[PC].use_bottom_half = 1;
							++line;
						}
						consume_label(program[PC].tgt, &line);
					} else {
						uint16_t r;
						// it's a value
						sscanf(line, "%"SCNx16, &r);
						program[PC].opcode |= (r >> 8);
						program[PC+1].opcode = r&0xFF;
					}
					++PC;
					break;

				case E1_OP_FMT_IMM:
					program[PC+1].line_number = line_number;
					if (islabel(line)) {
						// it's a label
						if (*line == '<') {
							program[PC].use_top_half = 1;
							++line;
						} else if (*line == '>') {
							program[PC].use_bottom_half = 1;
							++line;
						}
						consume_label(program[PC].tgt, &line);
					} else {
						uint8_t r;
						// it's a value
						sscanf(line, "%"SCNx8, &r);
						program[PC+1].opcode = r;
					}
					++PC;
					break;
				case E1_OP_FMT_R:
					if (islabel(line)) {
						// it's a label
						if (*line == '<') {
							program[PC].use_top_half = 1;
							++line;
						} else if (*line == '>') {
							program[PC].use_bottom_half = 1;
							++line;
						}
						consume_label(program[PC].tgt, &line);
					} else {
						uint8_t r;
						// it's a value
						sscanf(line, "%"SCNx8, &r);
						if (r > 0xF) {
							printf("line %d: 4-bit r value out of range %x\n", program[PC].line_number, r);
							exit(-1);
						}
						program[PC].opcode |= (r & 0xF);
					}
					break;
				case E1_OP_FMT_SB:
					{
						int s, b;
						sscanf(line, "%d, %d", &s, &b);
						program[PC].opcode |= ((s & 7) << 1) | (b & 1);
					}
					break;
				case E1_OP_FMT_FULL:
					break;
			}
			break;
		}
	}
	
	++PC;
	PC &= 0x3FF;
	if (!PC) {
		printf("Warning line %d: We've wrapped PC around back to 0\n", program[PC].line_number);
	}
	if (!e1_opcodes[x].opname) {
		printf("Line %d: Malformed line: '%s'\n", line_number, line);
		exit(-1);
	}
}	

void compile(char *line)
{
	strcpy(program[PC].line, line);
	// skip leading white space
	consume_whitespace(&line);
	if (!*line || *line == ';') {
		// blank line or comment
		return;
	}
	// is it .ORG ?
	if (!memcmp(line, ".ORG ", 5)) {
		line += 5;
		sscanf(line, "%"SCNx16, &PC);
	} else if (!memcmp(line, ".EQU ", 5)) {
		int x;
		line += 5;
		consume_whitespace(&line);
		for (x = 0; x < PROG_SIZE; x++) {
			if (symbols[x].label[0] == 0) {
				consume_label(symbols[x].label, &line);
				consume_whitespace(&line);
				sscanf(line, "%"SCNx8, &symbols[x].value);
				break;
			}
		}
	} else if (!memcmp(line, ".ALIGN ", 7)) {
		uint8_t x;
		line += 7;
		consume_whitespace(&line);
		sscanf(line, "%"SCNx8, &x);
		if (!x) {
			printf("Line %d: Invalid alignment %x specified\n", line_number, x);
			exit(-1);
		}
		while (PC % x) {
			++PC;
		}
	} else if (!memcmp(line, ".DB ", 4)) {
		uint8_t x;
		if (program[PC].line_number == -1) {
			// todo: allow symbols/labels here
			line += 4;
			consume_whitespace(&line);
			sscanf(line, "%"SCNx8, &x);
			program[PC].opcode = x;
			program[PC].line_number = line_number;
			++PC;
		} else {
			printf("Line %d: .DB directive on address that was already programmed on line %d\n", line_number, program[PC].line_number);
			exit(-1);
		}
	} else if (line[0] == ':') {
		// it's a label
		++line;
		consume_label(program[PC].label, &line);
	} else {
		compile_exec1(line);
	}
}

int find_target(int x)
{
	int y;
	uint8_t d;

	for (y = 0; y < PROG_SIZE; y++) {
		if (!strcmp(program[y].label, program[x].tgt)) {
			return y;
		}
	}
	for (y = 0; y < PROG_SIZE; y++) {
		if (!strcmp(symbols[y].label, program[x].tgt)) {
			return symbols[y].value;
		}
	}
	if (sscanf(program[x].tgt, "%"SCNx8, &d) == 1) {
		return d;
	}
	printf("Line %d: Target '%s' not found!\n", program[x].line_number, program[x].tgt);
	exit(-1);
}

void resolve_exec1(int x)
{
	int y;
	switch (e1_opcodes[program[x].opidx].fmt) {
		case E1_OP_FMT_R:
			if (program[x].tgt[0]) {
				y = find_target(x);
				if (program[x].use_top_half) {
					y >>= 8;
				} else if (program[x].use_bottom_half) {
					y &= 0xFF;
				}
				if (y > 15) {
					printf("line %d: Invalid 4-bit r-value %x at program offset %2x\n", program[x].line_number, y, x);
					exit(-1);
				} 
				program[x].opcode |= y & 0xF;
			}
			break;
		case E1_OP_FMT_IMM: // imms
			if (program[x].tgt[0]) {
				// jumping to a target 
				y = find_target(x);
				if (program[x].use_top_half) {
					y >>= 8;
				} else if (program[x].use_bottom_half) {
					y &= 0xFF;
				}
				program[x+1].opcode = y;
			}
			break;
		case E1_OP_FMT_IMM12: // relocations (JMP/CALL/etc)
			if (program[x].tgt[0]) {
				// jumping to a target 
				y = find_target(x);
				if (program[x].use_top_half) {
					y >>= 8;
				} else if (program[x].use_bottom_half) {
					y &= 0xFF;
				}
				program[x].opcode |= (y >> 12);
				program[x+1].opcode = (y & 0xFF);
			}
			break;
		case E1_OP_FMT_IMMS: // 12 => 8-bit immediates
			if (program[x].tgt[0]) {
				// jumping to a target 
				y = find_target(x);
				if (program[x].use_top_half) {
					y >>= 8;
				} else if (program[x].use_bottom_half) {
					y &= 0xFF;
				}
				if (y & 0xF) {
					printf("line %d: Invalid SAI target %x\n", program[x].line_number, y);
					exit(-1);
				}
				program[x+1].opcode = y >> 4;
			}
			break;
	}
}

void resolve_labels(void)
{
	int x;
	
	for (x = 0; x < PROG_SIZE; x++) {
		resolve_exec1(x);
	}
}

int main(int argc, char **argv)
{
	char outname[128];
	char linebuf[256];
	FILE *f;
	int x, y;
	
	if (argc != 2) {
		printf("Usage: %s input.s\n", argv[0]);
		return 0;
	}
	sprintf(outname, "%s.hex", argv[1]);
	memset(&program, 0, sizeof program);
	memset(&symbols, 0, sizeof symbols);
	
	for (x = 0; x < PROG_SIZE; x++) {
		program[x].opcode = 0xE6; // NOP
		program[x].line_number = -1;
	}
	
	f = fopen(argv[1], "r");
	if (f) {
		while (fgets(linebuf, sizeof(linebuf) - 2, f)) {
			compile(linebuf);
			++line_number;
		}
		fclose(f);
	}
	resolve_labels();
	f = fopen(outname, "w");
	fprintf(f, "#File_format=Hex\n#Address_depth=%d\n#Data_width=8\n", PROG_SIZE);
	for (x = 0; x < PROG_SIZE; x++) {
		fprintf(f, "%02X\n", program[x].opcode);
	}
	fclose(f);

	for (x = y = 0; x < PROG_SIZE; x++) {
		if (program[x].line_number != -1) {
			++y;
		}
	}
	printf("%s created, used %d (%d%%) out of %d bytes.\n", outname, y, (y * 100) / PROG_SIZE, PROG_SIZE);
	if (y > (PROG_SIZE-(PROG_SIZE/10)) && y != PROG_SIZE) {
		// find the user some space
		printf("Limited free space here's a map of free space:\n");
		for (x = 0; x < PROG_SIZE; x++) {
			if (program[x].line_number == -1) {
				printf("ROM[%x] is free\n", x);
			}
		}
	}
	printf("Symbols: \n");
	for (x = 0; x < PROG_SIZE; x++) {
		if (symbols[x].label[0]) {
			printf("Symbol %s == %x\n", symbols[x].label, symbols[x].value);
		}
	}
	printf("Listing: \n");
	for (x = 0; x < PROG_SIZE; x++) {
		if (program[x].line_number != -1) {
			if (program[x].label[0]) {
				printf("[%-15s ", program[x].label);
			} else {
				printf("[%16s", "");
			}
			strcpy(linebuf, program[x].line);
			linebuf[20] = 0;
			for (y = 0; linebuf[y]; y++) {
				if (linebuf[y] == '\r' || linebuf[y] == '\n') {
					linebuf[y] = 0;
					break;
				}
				if (linebuf[y] == '\t') {
					linebuf[y] = ' ';
				}
			}
			printf("0x%02X]: 0x%02X ; %-20s (%s:%d)\n", x, program[x].opcode, linebuf, argv[1], program[x].line_number);
		}
	}
	return 0;
}
