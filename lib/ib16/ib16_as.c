#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <inttypes.h>

#define PROG_SIZE 4096

// the entire program can only be upto PROG_SIZE bytes so just make a simple map here
struct {
	uint16_t opcode;
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
	uint16_t value;
} symbols[PROG_SIZE];

int line_number = 1;
uint16_t PC = 0;
uint16_t bin_start = 0;

/* bare bones assembler, allows whitespace and comments with ';'
 * 
 * a line starts with either ".ORG %x" to reset the orgiin or
 * ":%s" to denote a label or anything else to denote an instruction
 * 
 * There's three types of opcodes Xr where r is a 4-bit imm, 
 * or Xsb where s is a 3-bit imm and b is a 1-bit imm,
 * or XX where it's just a full byte with no operands
 */

#define OP_FMT_3OP 0
#define OP_FMT_2OP 1
#define OP_FMT_8IMM 2
#define OP_FMT_12IMM 3
#define OP_FMT_9SIMM 4
#define OP_FMT_LITERAL 5
#define OP_FMT_NONE 6

// instruction table
const struct {
	char *opname;
	uint16_t opcode;
	int fmt;
} e1_opcodes[] = {
	{ "", 			0x0000, OP_FMT_LITERAL },
	{ "MUL",		0x0000, OP_FMT_3OP },
	{ "LDI",		0x1000, OP_FMT_8IMM },
	{ "ADD",		0x2000, OP_FMT_3OP },
	{ "ADC",		0x3000, OP_FMT_3OP },
	{ "SUB",		0x4000, OP_FMT_3OP },
	{ "XOR",		0x5000, OP_FMT_3OP },
	{ "AND",		0x6000, OP_FMT_3OP },
	{ "OR",			0x7000, OP_FMT_3OP },
	{ "SHR",		0x8000, OP_FMT_2OP },
	{ "SAR",		0x8010, OP_FMT_2OP },
	{ "ROR",		0x8020, OP_FMT_2OP },
	{ "ROL",		0x8030, OP_FMT_2OP },
	{ "SWAP",		0x8040, OP_FMT_2OP },	
	{ "INC",		0x8050, OP_FMT_2OP },	
	{ "DEC",		0x8060, OP_FMT_2OP },	
	{ "NOT",		0x8070, OP_FMT_2OP },	
	{ "LDM",		0x9000, OP_FMT_3OP },
	{ "STM",		0xA000, OP_FMT_3OP },
	{ "CALL",		0xB000, OP_FMT_12IMM },
	{ "RET",		0xC000, OP_FMT_NONE },
	{ "JMP",		0xD000, OP_FMT_9SIMM },
	{ "JC",			0xD200, OP_FMT_9SIMM },
	{ "JNC",		0xD400, OP_FMT_9SIMM },
	{ "JZ",			0xD600, OP_FMT_9SIMM },
	{ "JNZ",		0xD800, OP_FMT_9SIMM },
	{ "SRES",		0xE000, OP_FMT_8IMM },
	{ "RETI",		0xF000, OP_FMT_NONE },
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
				case OP_FMT_3OP: // "d, a, b"
				{
					unsigned r_d, r_a, r_b;
					sscanf(line, "%u, %u, %u", &r_d, &r_a, &r_b);
					r_d &= 0xF;
					r_a &= 0xF;
					r_b &= 0xF;
					program[PC].opcode |= (r_d << 8) | (r_a << 4) | r_b;
					break;
				}
				case OP_FMT_2OP: // "d, a"
				{
					unsigned r_d, r_a;
					sscanf(line, "%u, %u", &r_d, &r_a);
					r_d &= 0xF;
					r_a &= 0xF;
					program[PC].opcode |= (r_d << 8) | r_a;
					break;
				}
				case OP_FMT_8IMM: // hex val
				{
					int r_a;
					if (strstr(line, ",") != NULL && sscanf(line, "%d, ", &r_a) == 1) {
						program[PC].opcode |= (r_a&0xF) << 8;
						while (line && *line != ',') ++line;
						++line;
					}
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
						program[PC].opcode |= r & 0xFF;
					}
					break;
				}
				case OP_FMT_12IMM: // hex val
				{
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
						program[PC].opcode |= r & 0xFFF;
					}
					break;
				}
				case OP_FMT_9SIMM: // hex val
				{
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
						int16_t r;
						int16_t off;
						// it's a value
						sscanf(line, "%"SCNx16, &r);
						// need to compute offset from PC+2 as a halved signed 9-bit value
						off = (r - PC - 1)  & 0x1FF;
						program[PC].opcode |= off & 0xFFF;
					}
					break;
				}
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
		PC >>= 1;
	} else 	if (!memcmp(line, ".BIN_START ", 11)) {
		line += 11;
		sscanf(line, "%"SCNx16, &bin_start);
	} else if (!memcmp(line, ".EQU ", 5)) {
		int x;
		line += 5;
		consume_whitespace(&line);
		for (x = 0; x < PROG_SIZE; x++) {
			if (symbols[x].label[0] == 0) {
				consume_label(symbols[x].label, &line);
				consume_whitespace(&line);
				sscanf(line, "%"SCNx16, &symbols[x].value);
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
	} else if (!memcmp(line, ".DW ", 4)) {
		if (program[PC].line_number == -1) {
			line += 4;
			consume_whitespace(&line);
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
				program[PC].opcode = r;
			}
			program[PC].line_number = line_number;
			program[PC].opidx = 0;
			++PC;
		} else {
			printf("Line %d: .DW directive on address that was already programmed on line %d\n", line_number, program[PC].line_number);
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
	uint16_t d;

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
	if (sscanf(program[x].tgt, "%"SCNx16, &d) == 1) {
		return d;
	}
	printf("Line %d: Target '%s' not found!\n", program[x].line_number, program[x].tgt);
	exit(-1);
}

void resolve_exec1(int x)
{
	int16_t y;

	switch (e1_opcodes[program[x].opidx].fmt) {
		case OP_FMT_8IMM:
			if (program[x].tgt[0]) {
				y = find_target(x);
				if (program[x].use_top_half) {
					y >>= 8;
				} else if (program[x].use_bottom_half) {
					y &= 0xFF;
				}
				program[x].opcode |= y & 0xFF;
			}
			break;
		case OP_FMT_12IMM: //CALL
			if (program[x].tgt[0]) {
				// jumping to a target 
				y = find_target(x);
				if (program[x].use_top_half) {
					y >>= 8;
				} else if (program[x].use_bottom_half) {
					y &= 0xFF;
				}
				program[x].opcode |= y & 0xFFF;
			}
			break;
		case OP_FMT_9SIMM: // Jumps
			if (program[x].tgt[0]) {
				int16_t off;
				// jumping to a target 
				y = find_target(x);
				if (program[x].use_top_half) {
					y >>= 8;
				} else if (program[x].use_bottom_half) {
					y &= 0xFF;
				}
				off = (y - x - 1)  & 0x1FF;
				program[x].opcode |= off;
			}
			break;
		case OP_FMT_LITERAL:
			if (program[x].tgt[0]) {
				// jumping to a target 
				y = find_target(x);
				if (program[x].use_top_half) {
					y >>= 8;
				} else if (program[x].use_bottom_half) {
					y &= 0xFF;
				}
				program[x].opcode = y;
			}
			break;
		default:
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
		program[x].opcode = 0x0000; // MOV 0,0
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
	sprintf(outname, "%s.bin", argv[1]);
	f = fopen(outname, "w");
	for (x = bin_start; x < PROG_SIZE; x++) {
		fputc(program[x].opcode&0xFF, f);
		fputc((program[x].opcode>>8)&0xFF, f);
	}
	fclose(f);
	
	sprintf(outname, "%s.hex", argv[1]);
	f = fopen(outname, "w");
	//fprintf(f, "#File_format=Hex\n#Address_depth=%d\n#Data_width=8\n", PROG_SIZE);
	for (x = 0; x < PROG_SIZE; x++) {
		fprintf(f, "%02X\n", (program[x].opcode)&0xFF);
		fprintf(f, "%02X\n", (program[x].opcode>>8)&0xFF);
	}
	fclose(f);

	for (x = y = 0; x < PROG_SIZE; x++) {
		if (program[x].line_number != -1) {
			++y;
		}
	}
	printf("%s created, used %d (%d%%) out of %d words.\n", outname, y, (y * 100) / (PROG_SIZE - bin_start), PROG_SIZE - bin_start);
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
			printf("0x%04X]: 0x%04X ; %-20s (%s:%d)\n", x*2, program[x].opcode, linebuf, argv[1], program[x].line_number);
		}
	}
	return 0;
}
