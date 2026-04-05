/* Simple assembler for the ittybitty */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <inttypes.h>

// max program size is the full 64KB though in practice smaller than that since you want stack/ISR/mmio
#define MAX_PROG_SIZE 32768

// a compiler state
struct compiler_state {
	int prog_size;
	char *cur_filename;

	// the entire program can only be upto PROG_SIZE bytes so just make a simple map here
	struct {
		uint16_t opcode;
		char label[64];
		char tgt[64];
		int use_top_half;
		int use_bottom_half;
		int line_number;
		char *fname;
		int opidx;
		char line[512];
	} program[MAX_PROG_SIZE];

	struct {
		char label[64];
		uint16_t value;
	} symbols[MAX_PROG_SIZE];

	int line_number;
	uint16_t PC;
	uint16_t bin_start;
};

// operand formats for various opcodes
#define OP_FMT_3OP 		0		// ALU 3 operand format R[d] = R[a] op R[b]
#define OP_FMT_2OP 		1		// ALU 2 operand format R[d] = op R[b]
#define OP_FMT_2OPALU 	2		// ALU 2 operand carry format carry = R[a] op R[b]
#define OP_FMT_2OPMOV 	3		// ALU 2 R[d] = R[a]
#define OP_FMT_1OP 		4		// ALU 1 operand format op R[d] 
#define OP_FMT_8IMM 	5		// 8IMM format r[d] = IMM
#define OP_FMT_12IMMT 	6		// 12IMMT format PC = 12IMMT << 4
#define OP_FMT_9SIMM 	7		// 9SIMM format PC += signed(9SIMM) << 1
#define OP_FMT_LITERAL 	8		// 16 bit of raw data
#define OP_FMT_NONE 	9

// instruction table
const struct {
	char *opname;
	uint16_t opcode;
	int fmt;
} e1_opcodes[] = {
// pseudo opcodes
	{ "", 			0x0000, OP_FMT_LITERAL },
	{ "PUSH",		0xA0FF, OP_FMT_1OP },	// STM d,F,F
	{ "POP",		0x90FF, OP_FMT_1OP },   // LDM d,F,F
	{ "MOV",		0x5000, OP_FMT_2OPMOV }, // AND d,a,a (moves a to d)
// real opcodes
	{ "LDI",		0x0000, OP_FMT_8IMM },
	{ "ADD",		0x1000, OP_FMT_3OP },
	{ "ADC",		0x2000, OP_FMT_3OP },
	{ "SUB",		0x3000, OP_FMT_3OP },
	{ "XOR",		0x4000, OP_FMT_3OP },
	{ "AND",		0x5000, OP_FMT_3OP },
	{ "OR",			0x6000, OP_FMT_3OP },
	{ "CMPLT", 		0x7000, OP_FMT_2OPALU },
	{ "CMPEQ", 		0x7100, OP_FMT_2OPALU },
	{ "CMPGT", 		0x7200, OP_FMT_2OPALU },
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
	{ "LCALL",		0xB000, OP_FMT_12IMMT },
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

void consume_fname(char *dest, char **s)
{
	while (isalnum(**s) || **s == '/' || **s == '.' || **s == '_') {
		*dest++ = *((*s)++);
	}
	*dest++ = 0;
}

void compile_opcodes(struct compiler_state *state, char *line)
{
	int x;
	for (x = 0; e1_opcodes[x].opname; x++) {
		if (!memcmp(line, e1_opcodes[x].opname, strlen(e1_opcodes[x].opname)) && iswhitespace(&line[strlen(e1_opcodes[x].opname)])) {
			// matched an opcode
			line += strlen(e1_opcodes[x].opname);
			consume_whitespace(&line);
			state->program[state->PC].opcode = e1_opcodes[x].opcode;
			state->program[state->PC].opidx = x;
			if (state->program[state->PC].line_number == -1) {
				state->program[state->PC].line_number = state->line_number;
				state->program[state->PC].fname = state->cur_filename;
			} else {
				printf("line %d: byte location %x already was programmed on line %d\n", state->line_number, state->PC, state->program[state->PC].line_number);
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
					state->program[state->PC].opcode |= (r_d << 8) | (r_a << 4) | r_b;
					break;
				}
				case OP_FMT_2OP: // "d, a"
				{
					unsigned r_d, r_a;
					sscanf(line, "%u, %u", &r_d, &r_a);
					r_d &= 0xF;
					r_a &= 0xF;
					state->program[state->PC].opcode |= (r_d << 8) | r_a;
					break;
				}
				case OP_FMT_2OPALU: // "a, b"
				{
					unsigned r_a, r_b;
					sscanf(line, "%u, %u", &r_a, &r_b);
					r_a &= 0xF;
					r_b &= 0xF;
					state->program[state->PC].opcode |= (r_a << 4) | r_b;
					break;
				}
				case OP_FMT_2OPMOV: // "a, b"
				{
					unsigned r_a, r_b;
					sscanf(line, "%u, %u", &r_a, &r_b);
					r_a &= 0xF;
					r_b &= 0xF;
					state->program[state->PC].opcode |= (r_a << 8) | (r_b << 4) | r_b;
					break;
				}
				case OP_FMT_1OP: // "d"
				{
					unsigned r_d;
					sscanf(line, "%u", &r_d);
					r_d &= 0xF;
					state->program[state->PC].opcode |= (r_d << 8);
					break;
				}
				case OP_FMT_8IMM: // hex val
				{
					int r_a;
					if (strstr(line, ",") != NULL && sscanf(line, "%d, ", &r_a) == 1) {
						state->program[state->PC].opcode |= (r_a&0xF) << 8;
						while (line && *line != ',') ++line;
						++line;
					}
					if (islabel(line)) {
						// it's a label
						if (*line == '<') {
							state->program[state->PC].use_top_half = 1;
							++line;
						} else if (*line == '>') {
							state->program[state->PC].use_bottom_half = 1;
							++line;
						}
						consume_label(state->program[state->PC].tgt, &line);
					} else {
						uint8_t r;
						// it's a value
						sscanf(line, "%"SCNx8, &r);
						state->program[state->PC].opcode |= r & 0xFF;
					}
					break;
				}
				case OP_FMT_12IMMT:
				{
					if (islabel(line)) {
						// it's a label
						if (*line == '<') {
							state->program[state->PC].use_top_half = 1;
							++line;
						} else if (*line == '>') {
							state->program[state->PC].use_bottom_half = 1;
							++line;
						}
						consume_label(state->program[state->PC].tgt, &line);
					} else {
						uint16_t r;
						// it's a value
						sscanf(line, "%"SCNx16, &r);
						state->program[state->PC].opcode |= ((r >> 4) & 0xFFF);
					}
					break;
				}
				case OP_FMT_9SIMM: // hex val
				{
					if (islabel(line)) {
						// it's a label
						if (*line == '<') {
							state->program[state->PC].use_top_half = 1;
							++line;
						} else if (*line == '>') {
							state->program[state->PC].use_bottom_half = 1;
							++line;
						}
						consume_label(state->program[state->PC].tgt, &line);
					} else {
						int16_t r;
						int16_t off;
						// it's a value
						sscanf(line, "%"SCNx16, &r);
						// need to compute offset from PC+2 as a halved signed 9-bit value
						off = ((r / 2) - state->PC - 1)  & 0x1FF;
						state->program[state->PC].opcode |= off & 0xFFF;
					}
					break;
				}
			}
			break;
		}
	}
	
	++(state->PC);
	if (!state->PC) {
		printf("Warning line %d: We've wrapped PC around back to 0\n", state->program[state->PC].line_number);
	}
	if (!e1_opcodes[x].opname) {
		printf("Line %d: Malformed line: '%s'\n", state->line_number, line);
		exit(-1);
	}
}	

void compile(struct compiler_state *state, char *line)
{
	strcpy(state->program[state->PC].line, line);
	// skip leading white space
	consume_whitespace(&line);
	if (!*line || *line == ';') {
		// blank line or comment
		return;
	}
	// is it .ORG ?
	if (!memcmp(line, ".ORG ", 5)) {
		line += 5;
		sscanf(line, "%"SCNx16, &state->PC);
		state->PC >>= 1;
	} else if (!memcmp(line, ".PROG_SIZE ", 11)) {
		line += 11;
		sscanf(line, "%d", &state->prog_size); 
	} else if (!memcmp(line, ".BIN_START ", 11)) {
		line += 11;
		sscanf(line, "%"SCNx16, &state->bin_start);
		state->bin_start >>= 1;
	} else if (!memcmp(line, ".EQU ", 5)) {
		int x;
		line += 5;
		consume_whitespace(&line);
		for (x = 0; x < MAX_PROG_SIZE; x++) {
			if (state->symbols[x].label[0] == 0) {
				consume_label(state->symbols[x].label, &line);
				consume_whitespace(&line);
				sscanf(line, "%"SCNx16, &state->symbols[x].value);
				break;
			}
		}
	} else if (!memcmp(line, ".ALIGN ", 7)) {
		uint8_t x;
		line += 7;
		consume_whitespace(&line);
		sscanf(line, "%"SCNx8, &x);
		if (!x) {
			printf("Line %d: Invalid alignment %x specified\n", state->line_number, x);
			exit(-1);
		}
		while (state->PC % x) {
			++state->PC;
		}
	} else if (!memcmp(line, ".DW ", 4)) {
		if (state->program[state->PC].line_number == -1) {
			line += 4;
			consume_whitespace(&line);
			if (islabel(line)) {
				// it's a label
				if (*line == '<') {
					state->program[state->PC].use_top_half = 1;
					++line;
				} else if (*line == '>') {
					state->program[state->PC].use_bottom_half = 1;
					++line;
				}
				consume_label(state->program[state->PC].tgt, &line);
			} else {
				uint16_t r;
				// it's a value
				sscanf(line, "%"SCNx16, &r);
				state->program[state->PC].opcode = r;
			}
			state->program[state->PC].line_number = state->line_number;
			state->program[state->PC].fname = state->cur_filename;
			state->program[state->PC].opidx = 0;
			++(state->PC);
		}
	} else if (!memcmp(line, ".DS ", 4)) {
		uint8_t buf[256];
		int dsi, slen = 0;
		memset(buf, 0, sizeof buf);
		line += 4;
		consume_whitespace(&line);
		// scan to first '
		while (*line && *line != '\'') {
			++line;
		}
		++line;
		while (slen < (sizeof(buf) - 1) && *line != '\'' && *line) {
			buf[slen++] = *line++;
		}
		++slen;				  // include NUL byte
		if (slen & 1) ++slen; // force even
		for (dsi = 0; dsi < slen; dsi += 2) {
			if (state->program[state->PC].line_number == -1) {
				uint16_t r;
				// it's a value
				r = ((uint16_t)buf[dsi+1] << 8) | buf[dsi];
				state->program[state->PC].opcode = r;
				state->program[state->PC].line_number = state->line_number;
				state->program[state->PC].fname = state->cur_filename;
				state->program[state->PC].opidx = 0;
				++(state->PC);
			} else {
				printf("Line %d: .DS directive on address that was already programmed on line %d\n", state->line_number, state->program[state->PC].line_number);
				exit(-1);
			}
		}
	} else if (!memcmp(line, ".DUP ", 4)) {
		int x, slen = 0;
		line += 4;
		consume_whitespace(&line);
		sscanf(line, "%x", &slen); // # of bytes
		if (slen & 1) ++slen; // force even
		for (x = 0; x < slen; x += 2) {
			if (state->program[state->PC].line_number == -1) {
				state->program[state->PC].opcode = 0;
				state->program[state->PC].line_number = state->line_number;
				state->program[state->PC].fname = state->cur_filename;
				state->program[state->PC].opidx = 0;
				++(state->PC);
			} else {
				printf("Line %d: .DUP directive on address that was already programmed on line %d\n", state->line_number, state->program[state->PC].line_number);
				exit(-1);
			}
		}
	} else if (!memcmp(line, ".INC ", 5)) {
		char *tmpfname = state->cur_filename;
		int tmpln = state->line_number;
		char tmpline[512];
		char newfname[512];
		FILE *f;
		
		// skip to filename
		line += 5;
		consume_whitespace(&line);
		
		// consume filename
		consume_fname(newfname, &line);
		state->cur_filename = strdup(newfname);
		state->line_number  = 1;
		f = fopen(state->cur_filename, "r");
		if (!f) {
			printf("Could not open include file '%s' from %s:%d\n", state->cur_filename, tmpfname, tmpln);
			exit(-1);
		}
		
		// compile included file
		while (fgets(tmpline, sizeof(tmpline) - 1, f)) {
			compile(state, tmpline);
			++(state->line_number);
		}
		fclose(f);
		
		// resume parent file
		state->cur_filename = tmpfname;
		state->line_number = tmpln;
	} else if (line[0] == ':') {
		// it's a label
		++line;
		consume_label(state->program[state->PC].label, &line);
	} else {
		compile_opcodes(state, line);
	}
}

int find_target(struct compiler_state *state, int x)
{
	int y;
	uint16_t d;

	for (y = 0; y < MAX_PROG_SIZE; y++) {
		if (!strcmp(state->program[y].label, state->program[x].tgt)) {
			return y << 1; // labels are placed in the stream at word offsets so return the byte offset
		}
	}
	for (y = 0; y < MAX_PROG_SIZE; y++) {
		if (!strcmp(state->symbols[y].label, state->program[x].tgt)) {
			return state->symbols[y].value; // symbols are literal constants and should be returned verbatim
		}
	}
	if (sscanf(state->program[x].tgt, "%"SCNx16, &d) == 1) {
		return d;
	}
	printf("Line %d: Target '%s' not found!\n", state->program[x].line_number, state->program[x].tgt);
	exit(-1);
}

void resolve_labels(struct compiler_state *state)
{
	int16_t y;
	int x;
	
	for (x = 0; x < MAX_PROG_SIZE; x++) {
		switch (e1_opcodes[state->program[x].opidx].fmt) {
			case OP_FMT_8IMM:
				if (state->program[x].tgt[0]) {
					y = find_target(state, x);
					if (state->program[x].use_top_half) {
						y >>= 8;
					} else if (state->program[x].use_bottom_half) {
						y &= 0xFF;
					}
					state->program[x].opcode |= y & 0xFF;
				}
				break;
			case OP_FMT_12IMMT: //CALL
				if (state->program[x].tgt[0]) {
					// jumping to a target 
					y = find_target(state, x);
					if (state->program[x].use_top_half) {
						y >>= 8;
					} else if (state->program[x].use_bottom_half) {
						y &= 0xFF;
					}
					state->program[x].opcode |= (y >> 4) & 0xFFF;
				}
				break;
			case OP_FMT_9SIMM: // Jumps
				if (state->program[x].tgt[0]) {
					int16_t off;
					// jumping to a target 
					y = find_target(state, x) >> 1;
					if (state->program[x].use_top_half) {
						y >>= 8;
					} else if (state->program[x].use_bottom_half) {
						y &= 0xFF;
					}
					off = (y - x - 1)  & 0x1FF;
					state->program[x].opcode |= off;
				}
				break;
			case OP_FMT_LITERAL:
				if (state->program[x].tgt[0]) {
					// jumping to a target 
					y = find_target(state, x);
					if (state->program[x].use_top_half) {
						y >>= 8;
					} else if (state->program[x].use_bottom_half) {
						y &= 0xFF;
					}
					state->program[x].opcode = y;
				}
				break;
			default:
				break;
		}
	}
}

int main(int argc, char **argv)
{
	char outname[128];
	char linebuf[256];
	FILE *f;
	int x, y, z;
	struct compiler_state *state;
	
	state = calloc(1, sizeof *state);

	if (argc != 2) {
		printf("Usage: %s input.s\n", argv[0]);
		return 0;
	}
	sprintf(outname, "%s.hex", argv[1]);
	state->cur_filename = strdup(argv[1]);		 	// initial fname	
	state->prog_size    = 4096;				// default to 8KB programs
	state->line_number  = 1;
	
	for (x = 0; x < MAX_PROG_SIZE; x++) {
		state->program[x].opcode = 0x0000;
		state->program[x].line_number = -1;
	}
	
	// compile code
	f = fopen(argv[1], "r");
	if (f) {
		while (fgets(linebuf, sizeof(linebuf) - 2, f)) {
			compile(state, linebuf);
			++(state->line_number);
		}
		fclose(f);
	}
	resolve_labels(state);

	// output in various formats
	sprintf(outname, "%s.bin", argv[1]);
	f = fopen(outname, "wb");
	printf("Outputting binary: %d, %d\n", state->bin_start, state->prog_size);
	for (x = state->bin_start; x < state->bin_start + state->prog_size; x++) {
		fputc(state->program[x].opcode&0xFF, f);
		fputc((state->program[x].opcode>>8)&0xFF, f);
	}
	fclose(f);
	
	sprintf(outname, "%s.hex", argv[1]);
	f = fopen(outname, "w");
	//fprintf(f, "#File_format=Hex\n#Address_depth=%d\n#Data_width=8\n", prog_size);
	for (x = state->bin_start; x < state->bin_start + state->prog_size; x++) {
		fprintf(f, "%02X\n", (state->program[x].opcode)&0xFF);
		fprintf(f, "%02X\n", (state->program[x].opcode>>8)&0xFF);
	}
	fclose(f);

	for (x = y = 0; x < MAX_PROG_SIZE; x++) {
		if (state->program[x].line_number != -1) {
			++y;
		}
	}
	printf("%s created, used %d (%d%%) out of %d words.\n", outname, y, (y * 100) / (state->prog_size - state->bin_start), state->prog_size - state->bin_start);
	if (y > (state->prog_size-(state->prog_size/10)) && y != state->prog_size) {
		// find the user some space
		printf("Limited free space here's a map of free space:\n");
		for (x = 0; x < state->prog_size; x++) {
			if (state->program[x].line_number == -1) {
				printf("ROM[%x] is free\n", x);
			}
		}
	}
	printf("Verilog:\n");
	for (z = x = 0; z < state->prog_size && x < MAX_PROG_SIZE; x++) {
		if (state->program[x].line_number != -1) {
			++z;
			printf("8'h%02x: ib16_bus_data_out <= 16'h%02x%02x;\n", (x*2)&0xFF, state->program[x].opcode>>8, state->program[x].opcode&0xFF);
		}
	}
	
	printf("Symbols: \n");
	for (x = 0; x < state->prog_size; x++) {
		if (state->symbols[x].label[0]) {
			printf("Symbol %s == %x\n", state->symbols[x].label, state->symbols[x].value);
		}
	}
	printf("Listing: \n");
	for (z = x = 0; z < state->prog_size && x < MAX_PROG_SIZE; x++) {
		if (state->program[x].line_number != -1) {
			++z;
			if (state->program[x].label[0]) {
				printf("[%-15s ", state->program[x].label);
			} else {
				printf("[%16s", "");
			}
			strcpy(linebuf, state->program[x].line);
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
			printf("0x%04X]: 0x%04X ; %-20s (%s:%d)\n", x*2, state->program[x].opcode, linebuf, state->program[x].fname, state->program[x].line_number);
		}
	}
	return 0;
}
