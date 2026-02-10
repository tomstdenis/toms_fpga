#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <inttypes.h>

// the entire program can only be 256 bytes so just make a simple map here
struct {
	uint8_t opcode;
	char label[64];
	char tgt[64];
	int use_top_half;
	int use_bottom_half;
	int line_number;
} program[256];

struct {
	char label[64];
	uint8_t value;
} symbols[256];

int line_number = 1;
uint8_t PC = 0;

/* bare bones assembler, allows whitespace and comments with ';'
 * 
 * a line starts with either ".ORG %x" to reset the orgiin or
 * ":%s" to denote a label or anything else to denote an instruction
 * 
 * There's three types of opcodes Xr where r is a 4-bit imm, 
 * or Xsb where s is a 3-bit imm and b is a 1-bit imm,
 * or XX where it's just a full byte with no operands
 */

#define OP_FMT_R 0			// has an r
#define OP_FMT_SB 1			// has an s, b
#define OP_FMT_FULL 2		// no operands

// instruction table
const struct {
	char *opname;
	uint8_t opcode;
	int fmt;
} opcodes[] = {
	{ "LD", 0x00, OP_FMT_R },
	{ "ST", 0x10, OP_FMT_R },
	{ "SETB", 0x20, OP_FMT_SB },
	{ "ADD", 0x30, OP_FMT_R }, 
	{ "SUB", 0x40, OP_FMT_R }, 
	{ "EOR", 0x50, OP_FMT_R }, 
	{ "AND", 0x60, OP_FMT_R }, 
	{ "OR" , 0x70, OP_FMT_R }, 
	{ "JMP", 0x80, OP_FMT_R }, 
	{ "JNZ", 0x90, OP_FMT_R }, 
	{ "INC", 0xA0, OP_FMT_FULL },
	{ "DEC", 0xA1, OP_FMT_FULL },
	{ "ASL", 0xA2, OP_FMT_FULL },
	{ "LSR", 0xA3, OP_FMT_FULL },
	{ "ASR", 0xA4, OP_FMT_FULL },
	{ "ROL", 0xA6, OP_FMT_FULL },
	{ "ROR", 0xA7, OP_FMT_FULL },
	{ "SWAPR0", 0xA8, OP_FMT_FULL },
	{ "SWAPR1", 0xA9, OP_FMT_FULL },
	{ "SWAP", 0xA5, OP_FMT_FULL },
	{ "LDA", 0xAA, OP_FMT_FULL },
	{ "SIGT", 0xAB, OP_FMT_FULL },
	{ "SIEQ", 0xAC, OP_FMT_FULL },
	{ "SILT", 0xAD, OP_FMT_FULL },
	{ "NOT", 0xAE, OP_FMT_FULL },
	{ "CLR", 0xAF, OP_FMT_FULL },
	{ "LDIB", 0xB0, OP_FMT_R },
	{ "LDIT", 0xC0, OP_FMT_R },
	{ "OUTBIT", 0xD1, OP_FMT_FULL },
	{ "OUT", 0xD0, OP_FMT_FULL },
	{ "TGLBIT", 0xD2, OP_FMT_FULL },
	{ "INBIT", 0xD4, OP_FMT_FULL },
	{ "IN", 0xD3, OP_FMT_FULL },
	{ "JMPA", 0xD5, OP_FMT_FULL },
	{ "CALL", 0xD6, OP_FMT_FULL },
	{ "RET", 0xD7, OP_FMT_FULL },
	{ "SEI", 0xD8, OP_FMT_FULL },
	{ "RTI", 0xD9, OP_FMT_FULL },
	{ "WAIT0", 0xDA, OP_FMT_FULL },
	{ "WAIT1", 0xDB, OP_FMT_FULL },
	{ "ABS", 0xDC, OP_FMT_FULL },
	{ "NEG", 0xDD, OP_FMT_FULL },
	{ "WAITA", 0xDE, OP_FMT_FULL },
	{ "JSR", 0xE0, OP_FMT_R },
	{ "SBIT", 0xF0, OP_FMT_SB },
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
	return *s == '>' || *s == '<' || isalpha(*s);
}

void consume_label(char *dest, char **s)
{
	while (isalnum(**s)) {
		*dest++ = *((*s)++);
	}
	*dest++ = 0;
}

void compile(char *line)
{
	// skip leading white space
	consume_whitespace(&line);
	if (!*line || *line == ';') {
		// blank line or comment
		return;
	}
	// is it .ORG ?
	if (!memcmp(line, ".ORG ", 5)) {
		line += 5;
		sscanf(line, "%"SCNx8, &PC);
	} else if (!memcmp(line, ".EQU ", 5)) {
		int x;
		line += 5;
		consume_whitespace(&line);
		for (x = 0; x < 256; x++) {
			if (symbols[x].label[0] == 0) {
				consume_label(symbols[x].label, &line);
				consume_whitespace(&line);
				sscanf(line, "%"SCNx8, &symbols[x].value);
				break;
			}
		}
	} else if (line[0] == ':') {
		// it's a label
		++line;
		consume_label(program[PC].label, &line);
	} else {
		// it's an opcode
		int x;
		for (x = 0; opcodes[x].opname; x++) {
			if (!memcmp(line, opcodes[x].opname, strlen(opcodes[x].opname)) && iswhitespace(&line[strlen(opcodes[x].opname)])) {
				// matched an opcode
				line += strlen(opcodes[x].opname);
				consume_whitespace(&line);
				program[PC].opcode = opcodes[x].opcode;
				program[PC].line_number = line_number;
				switch (opcodes[x].fmt) {
					case OP_FMT_R:
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
					case OP_FMT_SB:
						{
							int s, b;
							sscanf(line, "%d, %d", &s, &b);
							program[PC].opcode |= ((s & 7) << 1) | (b & 1);
						}
						break;
					case OP_FMT_FULL:
						break;
				}
				break;
			}
		}
		++PC;
		if (!opcodes[x].opname) {
			printf("Line %d: Malformed line: '%s'\n", line_number, line);
			exit(-1);
		}
	}
}

int find_target(int x)
{
	int y;
	for (y = 0; y < 256; y++) {
		if (!strcmp(program[y].label, program[x].tgt)) {
			return y;
		}
	}
	for (y = 0; y < 256; y++) {
		if (!strcmp(symbols[y].label, program[x].tgt)) {
			return symbols[y].value;
		}
	}
	printf("Line %d: Target '%s' not found!\n", program[x].line_number, program[x].tgt);
	exit(-1);
}

void resolve_labels(void)
{
	int x, y;
	
	for (x = 0; x < 256; x++) {
		switch(program[x].opcode&0xF0){
			// generics
			case 0x00: // LD
			case 0x10: // ST
			case 0x30: // ADD
			case 0x40: // SUB
			case 0x50: // EOR
			case 0x60: // AND
			case 0x70: // OR
			case 0xB0: // LDIB
			case 0xC0: // LDIT
				if (program[x].tgt[0]) {
					y = find_target(x);
					if (program[x].use_top_half) {
						y >>= 4;
					} else if (program[x].use_bottom_half) {
						y &= 0xF;
					}
					if (y > 16) {
						printf("line %d: Invalid 4-bit r-value %x\n", program[x].line_number, y);
						exit(-1);
					} 
					program[x].opcode |= y & 0xF;
				}
				break;
			case 0x80: // JMP
				if (program[x].tgt[0]) {
					// jumping to a target 
					y = find_target(x);
					if (program[x].use_top_half) {
						y >>= 4;
					} else if (program[x].use_bottom_half) {
						y &= 0xF;
					}
					// can only jump PC+1..PC+16
					if ((y < (x+1)) || (y > x+16)) {
						printf("line %d: JMP to target %s is out of range on byte %d\n", program[x].line_number, program[x].tgt, x);
						exit(-1);
					}
					program[x].opcode |= (y - (x+1)) & 0x0F;
				}
				break;
			case 0x90: // JNZ
				if (program[x].tgt[0]) {
					// jumping to a target 
					y = find_target(x);
					if (program[x].use_top_half) {
						y >>= 4;
					} else if (program[x].use_bottom_half) {
						y &= 0xF;
					}
					// can only jump PC-1..PC-16
					if ((y >= x) || (y < x-16)) {
						printf("line %d: JNZ to target %s is out of range on byte %d\n", program[x].line_number, program[x].tgt, x);
						exit(-1);
					}
					program[x].opcode |= ((x-1)-y) & 0x0F;
				}
				break;
			case 0xE0: // JSR
				if (program[x].tgt[0]) {
					y = find_target(x);
					// if we're using a half make sure it's in the top 4 bits
					if (program[x].use_top_half) {
						y &= 0xF0;
					} else if (program[x].use_bottom_half) {
						y <<= 4;
					}
					if (y & 0x0F) {
						printf("line %d: JSR can only jump to 16 byte aligned targets %s (%x) is invalid.\n", program[x].line_number, program[x].tgt, y);
						exit(-1);
					} else {
						program[x].opcode |= ((y >> 4) & 0x0F);
					}
				}
				break;
		}
	}
}

int main(int argc, char **argv)
{
	char outname[128];
	char linebuf[256];
	FILE *f;
	int x;
	
	if (argc != 2) {
		printf("Usage: %s input.s\n", argv[0]);
		return 0;
	}
	sprintf(outname, "%s.hex", argv[1]);
	memset(&program, 0, sizeof program);
	memset(&symbols, 0, sizeof symbols);
	
	for (x = 0; x < 256; x++) {
		program[x].opcode = 0xAF; // CLR
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
	fprintf(f, "#File_format=Hex\n#Address_depth=256\n#Data_width=8\n");
	for (x = 0; x < 256; x++) {
		fprintf(f, "%02X\n", program[x].opcode);
	}
	fclose(f);
	return 0;
}
