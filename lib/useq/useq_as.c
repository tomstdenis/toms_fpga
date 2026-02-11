#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <inttypes.h>

// the entire program can only be 256 bytes so just make a simple map here
struct {
	int multi_byte; // does this opcode span into the next byte?
	int mode;		// 0 == EXEC1, 1 == EXEC2
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
int mode = 0;
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

#define E1_OP_FMT_R 0			// has an r
#define E1_OP_FMT_SB 1			// has an s, b
#define E1_OP_FMT_FULL 2		// no operands

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
	{ "JMP", 0x80, E1_OP_FMT_R }, 
	{ "JNZ", 0x90, E1_OP_FMT_R }, 
	{ "INC", 0xA0, E1_OP_FMT_FULL },
	{ "DEC", 0xA1, E1_OP_FMT_FULL },
	{ "ASL", 0xA2, E1_OP_FMT_FULL },
	{ "LSR", 0xA3, E1_OP_FMT_FULL },
	{ "ASR", 0xA4, E1_OP_FMT_FULL },
	{ "SWAP", 0xA5, E1_OP_FMT_FULL },
	{ "ROL", 0xA6, E1_OP_FMT_FULL },
	{ "ROR", 0xA7, E1_OP_FMT_FULL },
	{ "SWAPR0", 0xA8, E1_OP_FMT_FULL },
	{ "SWAPR1", 0xA9, E1_OP_FMT_FULL },
	{ "NOT", 0xAA, E1_OP_FMT_FULL },
	{ "CLR", 0xAB, E1_OP_FMT_FULL },
	{ "LDA", 0xAC, E1_OP_FMT_FULL },
	{ "SIGT", 0xAD, E1_OP_FMT_FULL },
	{ "SIEQ", 0xAE, E1_OP_FMT_FULL },
	{ "SILT", 0xAF, E1_OP_FMT_FULL },
	{ "LDIB", 0xB0, E1_OP_FMT_R },
	{ "LDIT", 0xC0, E1_OP_FMT_R },
	{ "OUT", 0xD0, E1_OP_FMT_FULL },
	{ "OUTBIT", 0xD1, E1_OP_FMT_FULL },
	{ "TGLBIT", 0xD2, E1_OP_FMT_FULL },
	{ "IN", 0xD3, E1_OP_FMT_FULL },
	{ "INBIT", 0xD4, E1_OP_FMT_FULL },
	{ "NEG", 0xD5, E1_OP_FMT_FULL },
	{ "SEI", 0xD6, E1_OP_FMT_FULL },
	{ "JMPA", 0xD7, E1_OP_FMT_FULL },
	{ "CALL", 0xD8, E1_OP_FMT_FULL },
	{ "RET", 0xD9, E1_OP_FMT_FULL },
	{ "RTI", 0xDA, E1_OP_FMT_FULL },
	{ "WAIT0", 0xDB, E1_OP_FMT_FULL },
	{ "WAIT1", 0xDC, E1_OP_FMT_FULL },
	{ "EXEC2", 0xDD, E1_OP_FMT_FULL },
	{ "WAITF", 0xDE, E1_OP_FMT_FULL },
	{ "WAITA", 0xDF, E1_OP_FMT_FULL },
	{ "JSR", 0xE0, E1_OP_FMT_R },
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
	return *s == '>' || *s == '<' || isalpha(*s);
}

void consume_label(char *dest, char **s)
{
	while (isalnum(**s)) {
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
			if (program[PC].line_number == -1) {
				program[PC].line_number = line_number;
			} else {
				printf("line %d: byte location %x already was programmed on line %d\n", line_number, PC, program[PC].line_number);
				exit(-1);
			}
			switch (e1_opcodes[x].fmt) {
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
	if (!PC) {
		printf("Warning line %d: We've wrapped PC around back to 0\n", program[PC].line_number);
	}
	if (!e1_opcodes[x].opname) {
		printf("Line %d: Malformed line: '%s'\n", line_number, line);
		exit(-1);
	}
}	

void compile_exec2(char *line)
{
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
	} else if (!memcmp(line, ".MODE ", 6)) {
		uint8_t x;
		line += 6;
		sscanf(line, "%"SCNu8, &x);
		if (x != 0 && x != 1) {
			printf("Line %d: Invalid .MODE selection (%u)\n", line_number, x);
			exit(-1);
		}
		mode = x;
	} else if (line[0] == ':') {
		// it's a label
		++line;
		consume_label(program[PC].label, &line);
	} else {
		// it's an opcode
		if (mode == 0) {
			compile_exec1(line);
		} else {
			compile_exec2(line);
		}
	}
}

int find_target(int x)
{
	int y;
	uint8_t d;
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
	if (sscanf(program[x].tgt, "%"SCNx8, &d) == 1) {
		return d;
	}
	printf("Line %d: Target '%s' not found!\n", program[x].line_number, program[x].tgt);
	exit(-1);
}

void resolve_exec1(int x)
{
	int y;
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
				if (y > 15) {
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

void resolve_exec2(int x)
{
	int y;
}

void resolve_labels(void)
{
	int x;
	
	for (x = 0; x < 256; x++) {
		if (program[x].mode == 0) {
			resolve_exec1(x);
		} else {
			resolve_exec2(x);
		}
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
	
	for (x = 0; x < 256; x++) {
		program[x].opcode = 0xAF; // CLR
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
	fprintf(f, "#File_format=Hex\n#Address_depth=256\n#Data_width=8\n");
	for (x = 0; x < 256; x++) {
		fprintf(f, "%02X\n", program[x].opcode);
	}
	fclose(f);

	for (x = y = 0; x < 256; x++) {
		if (program[x].line_number != -1) {
			++y;
		}
	}
	printf("%s created, used %d out of 256 bytes.\n", outname, y);
	if (y > 224 && y != 256) {
		// find the user some space
		printf("Limited free space here's a map of free space:\n");
		for (x = 0; x < 256; x++) {
			if (program[x].line_number == -1) {
				printf("ROM[%x] is free\n", x);
			}
		}
	}
	return 0;
}
