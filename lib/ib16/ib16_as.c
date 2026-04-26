/* Simple assembler for the ittybitty */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <inttypes.h>
#include <dirent.h>

// max program size is the full 64KB though in practice smaller than that since you want stack/ISR/mmio
#define MAX_PROG_SIZE 32768

// a compiler state
struct compiler_state {
	int prog_size;
	char *cur_filename;
	int reg_idx;

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
		int local;
		int save;
	} symbols[MAX_PROG_SIZE];

	int line_number;
	uint16_t PC;
	uint16_t bin_start;
};

void compile_file(struct compiler_state *state, char *fname);

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
	{ "XOR",		0x3000, OP_FMT_3OP },
	{ "AND",		0x4000, OP_FMT_3OP },
	{ "OR",			0x5000, OP_FMT_3OP },
	{ "CMPLT", 		0x6000, OP_FMT_2OPALU },
	{ "CMPEQ", 		0x6100, OP_FMT_2OPALU },
	{ "CMPGT", 		0x6200, OP_FMT_2OPALU },
	{ "SHR",		0x7000, OP_FMT_2OP },
	{ "SAR",		0x7010, OP_FMT_2OP },
	{ "ROR",		0x7020, OP_FMT_2OP },
	{ "ROL",		0x7030, OP_FMT_2OP },
	{ "SWAP",		0x7040, OP_FMT_2OP },
	{ "INC",		0x7050, OP_FMT_2OP },
	{ "DEC",		0x7060, OP_FMT_2OP },
	{ "NOT",		0x7070, OP_FMT_2OP },
	{ "NEG",		0x7080, OP_FMT_2OP },
	{ "SCC",		0x7090, OP_FMT_1OP },
	{ "SNZ",		0x70A0, OP_FMT_1OP },
	{ "ROLB",		0x70B0, OP_FMT_2OP },
	{ "RORB",		0x70C0, OP_FMT_2OP },
	{ "AJMPR",		0x8100, OP_FMT_2OPALU },
	{ "AJMP",		0x8000, OP_FMT_2OPALU },
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
	return *s == '>' || *s == '<' || *s == '_' || isalnum(*s);
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

int find_symbol(struct compiler_state *state, char *line, int only_sym)
{
	int y;
	char sym[512], *s;

	s = sym;
	memset(sym, 0, sizeof sym);
	while (!iswhitespace(line) && *line) {
		*s++ = *line++;
	}
	for (y = 0; y < MAX_PROG_SIZE; y++) {
		if (!memcmp(state->symbols[y].label, sym, strlen(state->symbols[y].label))) {
			int n = strlen(state->symbols[y].label);
			char *l = sym + n;
			if (*l == 0 || iswhitespace(l) || *l == ',') {
				return state->symbols[y].value; // symbols are literal constants and should be returned verbatim
			}
		}
	}
	if (!only_sym && sscanf(sym, "%x", &y) == 1) {
		return y;
	}
	return -1;
}

static unsigned str_to_op(struct compiler_state *state, char **line)
{
	unsigned x;
	if (!**line) {
		fprintf(stderr, "%s:%d unexpect end of line\n", state->cur_filename, state->line_number);
		exit(-1);
	}
	
	if (sscanf(*line, "%u", &x) == 1) {
	} else {
		int y;
		y = find_symbol(state, *line, 1);
		if (y < 0) {
			fprintf(stderr, "%s:%d operand symbol not defined\n", state->cur_filename, state->line_number);
			exit(-1);
		}
		x = y;
	}
	// now advance to , or NUL
	while (**line && **line != ',') {
		++(*line);
	}
	if (**line) {
		++(*line);
	}
	return x;
}

void compile_opcodes(struct compiler_state *state, char *line)
{
	int x;
	for (x = 0; e1_opcodes[x].opname; x++) {
		if (!memcmp(line, e1_opcodes[x].opname, strlen(e1_opcodes[x].opname)) && (!line[strlen(e1_opcodes[x].opname)] || iswhitespace(&line[strlen(e1_opcodes[x].opname)]))) {
			// matched an opcode
			line += strlen(e1_opcodes[x].opname);
			consume_whitespace(&line);
			state->program[state->PC].opcode = e1_opcodes[x].opcode;
			state->program[state->PC].opidx = x;
			if (state->program[state->PC].line_number == -1) {
				state->program[state->PC].line_number = state->line_number;
				state->program[state->PC].fname = state->cur_filename;
			} else {
				fprintf(stderr, "line %s:%d: byte location %x already was programmed on line %s:%d\n", state->cur_filename, state->line_number, state->PC, state->program[state->PC].fname, state->program[state->PC].line_number);
				exit(-1);
			}
			switch (e1_opcodes[x].fmt) {
				case OP_FMT_3OP: // "d, a, b"
				{
					unsigned r_d, r_a, r_b;
					r_d = str_to_op(state, &line);
					r_a = str_to_op(state, &line);
					r_b = str_to_op(state, &line);
					r_d &= 0xF;
					r_a &= 0xF;
					r_b &= 0xF;
					state->program[state->PC].opcode |= (r_d << 8) | (r_a << 4) | r_b;
					break;
				}
				case OP_FMT_2OP: // "d, a"
				{
					unsigned r_d, r_a;
					r_d = str_to_op(state, &line);
					r_a = str_to_op(state, &line);
					r_d &= 0xF;
					r_a &= 0xF;
					state->program[state->PC].opcode |= (r_d << 8) | r_a;
					break;
				}
				case OP_FMT_2OPALU: // "a, b"
				{
					unsigned r_a, r_b;
					r_a = str_to_op(state, &line);
					r_b = str_to_op(state, &line);
					r_a &= 0xF;
					r_b &= 0xF;
					state->program[state->PC].opcode |= (r_a << 4) | r_b;
					break;
				}
				case OP_FMT_2OPMOV: // "a, b"
				{
					unsigned r_a, r_b;
					r_a = str_to_op(state, &line);
					r_b = str_to_op(state, &line);
					r_a &= 0xF;
					r_b &= 0xF;
					state->program[state->PC].opcode |= (r_a << 8) | (r_b << 4) | r_b;
					break;
				}
				case OP_FMT_1OP: // "d"
				{
					unsigned r_d;
					r_d = str_to_op(state, &line);
					r_d &= 0xF;
					state->program[state->PC].opcode |= (r_d << 8);
					break;
				}
				case OP_FMT_8IMM: // hex val
				{
					int r_a;
					if (strstr(line, ",") != NULL) {
						if (sscanf(line, "%d, ", &r_a) == 1) {
						} else {
							// named reg?
							r_a = find_symbol(state, line, 1);
							if (r_a < 0) {
								fprintf(stderr, "Line %s:%d: Invalid register name [%s]\n", state->cur_filename, state->line_number, line);
								exit(-1);
							}
						}
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
		fprintf(stderr, "Line %s:%d: We've wrapped PC around back to 0\n", state->cur_filename, state->line_number);
	}
	if (!e1_opcodes[x].opname) {
		fprintf(stderr, "Line %s:%d: Malformed line: '%s'\n", state->cur_filename, state->line_number, line);
		exit(-1);
	}
}	

void insert_symbol(struct compiler_state *state, char *line, int reg)
{
	int x;
	for (x = 0; x < MAX_PROG_SIZE; x++) {
		if (state->symbols[x].label[0] == 0) {
			consume_label(state->symbols[x].label, &line);
			state->symbols[x].local = reg > 0 ? 1 : 0;
			state->symbols[x].save  = reg == 1;
			if (reg) {
				// assign new register
				if (state->reg_idx < 16) {
					state->symbols[x].value = state->reg_idx++;
				} else {
					fprintf(stderr, "%s:%d Out of registers\n", state->cur_filename, state->line_number);
					exit(-1);
				}
			} else {
				consume_whitespace(&line);
				sscanf(line, "%"SCNx16, &state->symbols[x].value);
			}
			break;
		}
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
		int y;
		line += 5;
		consume_whitespace(&line);
		y = find_symbol(state, line, 0);
		if (y >= 0) {
			state->PC = y >> 1;
		} else {
			fprintf(stderr, "Line %s:%d: Undefined symbol for ORG '%s'\n", state->cur_filename, state->line_number, line);
			exit(-1);
		}
	} else if (!memcmp(line, ".PROG_SIZE ", 11)) {
		int y;
		line += 11;
		y = find_symbol(state, line, 0);
		if (y >= 0) {
			state->prog_size = y;
		} else {
			fprintf(stderr, "Line %s:%d: Undefined symbol for PROG_SIZE '%s'\n", state->cur_filename, state->line_number, line);
			exit(-1);
		}
	} else if (!memcmp(line, ".BIN_START ", 11)) {
		line += 11;
		sscanf(line, "%"SCNx16, &state->bin_start);
		state->bin_start >>= 1;
	} else if (!memcmp(line, ".EQU ", 5)) {
		line += 5;
		consume_whitespace(&line);
		insert_symbol(state, line, 0);
	} else if (!memcmp(line, ".REG ", 5)) {
		line += 5;
		consume_whitespace(&line);
		insert_symbol(state, line, 1);
	} else if (!memcmp(line, ".IREG ", 6)) {
		line += 6;
		consume_whitespace(&line);
		insert_symbol(state, line, 2);
	} else if (!memcmp(line, ".PUSHREGS", 9)) {
		int x, y;
		line += 9;
		for (y = 1, x = 0; x < MAX_PROG_SIZE; x++) {
			if (state->symbols[x].local) {
				if (state->symbols[x].save) {
					char tmpline[32];
					sprintf(tmpline, "PUSH %d\n", y);
					compile_opcodes(state, tmpline);
				}
				++y;
			}
		}
		consume_whitespace(&line);
	} else if (!memcmp(line, ".POPREGS", 8)) {
		int x, y;
		line += 8;
		for (y = state->reg_idx - 1, x = MAX_PROG_SIZE - 1; x >= 0; x--) {
			if (state->symbols[x].local) {
				if (state->symbols[x].save) {
					char tmpline[32];
					sprintf(tmpline, "POP %d\n", y);
					compile_opcodes(state, tmpline);
				}
				--y;
				state->symbols[x].label[0] = 0; // delete local
			}
		}
		state->reg_idx = 1;
	} else if (!memcmp(line, ".ALIGN ", 7)) {
		uint8_t x;
		line += 7;
		consume_whitespace(&line);
		sscanf(line, "%"SCNx8, &x);
		if (!x) {
			fprintf(stderr, "Line %s:%d: Invalid alignment %x specified\n", state->cur_filename, state->line_number, x);
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
		} else {
			fprintf(stderr, "Line %s:%d PC==%04X was already programmed by %s:%d\n", state->cur_filename, state->line_number, state->PC, state->program[state->PC].fname, state->program[state->PC].line_number);
			exit(-1);
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
				fprintf(stderr, "Line %s:%d: .DS directive on address that was already programmed on line %d\n", state->cur_filename, state->line_number, state->program[state->PC].line_number);
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
				fprintf(stderr, "Line %s:%d: .DUP directive on address that was already programmed on line %d\n", state->cur_filename, state->line_number, state->program[state->PC].line_number);
				exit(-1);
			}
		}
	} else if (!memcmp(line, ".INC ", 5)) {
		char *tmpfname = state->cur_filename;
		int tmpln = state->line_number;
		char newfname[512];
		
		// skip to filename
		line += 5;
		consume_whitespace(&line);
		
		// consume filename
		consume_fname(newfname, &line);
		compile_file(state, newfname);
		
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

int find_target(struct compiler_state *state, int x, char **missing_symbol)
{
	int y;
	uint16_t d;

	*missing_symbol = NULL;
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
	*missing_symbol = state->program[x].tgt;
	return -1;
}

int resolve_labels(struct compiler_state *state, char **missing_symbol)
{
	int16_t y;
	int x, z;
	
	for (x = 0; x < MAX_PROG_SIZE; x++) {
		switch (e1_opcodes[state->program[x].opidx].fmt) {
			case OP_FMT_8IMM:
				if (state->program[x].tgt[0]) {
					y = z = find_target(state, x, missing_symbol);
					if (z < 0) {
						// symbol not found
						return -1;
					}
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
					y = z = find_target(state, x, missing_symbol);
					if (z < 0) {
						// symbol not found
						return -1;
					}
					if (state->program[x].use_top_half) {
						y >>= 8;
					} else if (state->program[x].use_bottom_half) {
						y &= 0xFF;
					}
					if (y & 0xF) { 
						fprintf(stderr, "Line %s:%d: Error, LCALL target must be 16-byte aligned\n", state->cur_filename, state->line_number);
						exit(-1);
					}
					state->program[x].opcode |= (y >> 4) & 0xFFF;
				}
				break;
			case OP_FMT_9SIMM: // Jumps
				if (state->program[x].tgt[0]) {
					int16_t off;
					// jumping to a target 
					y = z = find_target(state, x, missing_symbol);
					if (z < 0) {
						// symbol not found
						return -1;
					}
					y >>= 1; // convert to word offset from byte offset
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
					y = z = find_target(state, x, missing_symbol);
					if (z < 0) {
						// symbol not found
						return -1;
					}					
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
	return 0;
}

void compile_file(struct compiler_state *state, char *fname)
{
	FILE *f;
	char linebuf[256];
	f = fopen(fname, "r");
	if (!f) {
		fprintf(stderr, "File '%s' not found!\n", fname);
		exit(-1);
	}
	memset(linebuf, 0, sizeof linebuf);
	printf("Compiling %s...\n", fname);
	state->line_number = 1;
	state->cur_filename = strdup(fname);
	while (fgets(linebuf, sizeof(linebuf) - 1, f)) {
		int n = strlen(linebuf) - 1;
		while (linebuf[n] == '\r' || linebuf[n] == '\n') {
			linebuf[n--] = 0;
		}
		compile(state, linebuf);
		++(state->line_number);
	}
	fclose(f);
}

int scan_file(char *fname, char *missing_symbol)
{
	FILE *f;
	char linebuf[512], *line;
	
	f = fopen(fname, "r");
	if (!f) {
		fprintf(stderr, "Cannot open linker file %s\n", fname);
		exit(-1);
	}
	memset(linebuf, 0, sizeof linebuf);
	while (fgets(linebuf, sizeof(linebuf)-1, f)) {
		line = &linebuf[0];
		consume_whitespace(&line);
		if (line[0] == ':' && !memcmp(line+1, missing_symbol, strlen(missing_symbol))) {
			return 1;
		}
	}
	return 0;
}

int link(struct compiler_state *state, char *libdir, char *missing_symbol)
{
	DIR *d;
	struct dirent *de;
	
	// we scan libdir for any file that has a line starting with ":%s" (missing_symbol)
	d = opendir(libdir);
	if (!d) { 
		fprintf(stderr, "Could not open directory '%s'\n", libdir);
		exit(-1);
	}
	
	while ((de = readdir(d))) {
		if (de->d_type == DT_DIR) {
			// directories
			if (strcmp(de->d_name, ".") && strcmp(de->d_name, "..")) {
				char newdir[512];
				sprintf(newdir, "%s%s/", libdir, de->d_name);
				if (!link(state, newdir, missing_symbol)) {
					closedir(d);
					return 0;
				}
			}
		} else if (de->d_type == DT_REG) {
			// regular file
			char fname[512];
			sprintf(fname, "%s%s", libdir, de->d_name);
			if (scan_file(fname, missing_symbol)) {
				compile_file(state, fname);
				closedir(d);
				return 0;
			}
		}
	}
	closedir(d);
	return -1;
}

void emit_hexfile(struct compiler_state *state, char *fname)
{
	FILE *f;
	int x;
	f = fopen(fname, "w");
	if (!f) {
		fprintf(stderr, "Could not open the hex output file '%s'\n", fname);
		exit(-1);
	}
	
	fprintf(f, "#File_format=Hex\n#Address_depth=%d\n#Data_width=16\n", state->prog_size);
	for (x = state->bin_start; x < state->bin_start + state->prog_size; x++) {
		fprintf(f, "%02X", (state->program[x].opcode>>8)&0xFF);
		fprintf(f, "%02X\n", (state->program[x].opcode)&0xFF);
	}
	fclose(f);
}

void emit_monfile(struct compiler_state *state, char *fname)
{
	FILE *f;
	int x;
	f = fopen(fname, "w");
	if (!f) {
		fprintf(stderr, "Could not open the mon output file '%s'\n", fname);
		exit(-1);
	}
	
	for (x = state->bin_start; x < state->bin_start + state->prog_size; x++) {
		if (state->program[x].line_number != -1) {
			fprintf(f, "E%04X %02X %02X\n", x*2, 
				state->program[x].opcode>>8,
				state->program[x].opcode&0xFF); // x is the word address so double to get byte addr
		}
	}
	fclose(f);
}

void emit_binfile(struct compiler_state *state, char *fname)
{
	FILE *f;
	int x;

	f = fopen(fname, "wb");
	if (!f) {
		fprintf(stderr, "Could not open the bin output file '%s'\n", fname);
		exit(-1);
	}

	for (x = state->bin_start; x < state->bin_start + state->prog_size; x++) {
		fputc(state->program[x].opcode&0xFF, f);
		fputc((state->program[x].opcode>>8)&0xFF, f);
	}
	fclose(f);
}

void emit_romfile(struct compiler_state *state, char *fname)
{
	FILE *f;
	int x, z;
	f = fopen(fname, "w");
	if (!f) {
		fprintf(stderr, "Could not open the rom output file '%s'\n", fname);
		exit(-1);
	}

	for (z = x = 0; z < state->prog_size && x < MAX_PROG_SIZE; x++) {
		if (state->program[x].line_number != -1) {
			++z;
			fprintf(f, "8'h%02x: ib16_bus_data_out_reg <= 16'h%02x%02x;\n", (x*2)&0xFF, state->program[x].opcode>>8, state->program[x].opcode&0xFF);
		}
	}
	fclose(f);
}

void emit_lstfile(struct compiler_state *state, char *fname)
{
	FILE *f;
	int x, y, z;
	char linebuf[512];
	
	f = fopen(fname, "w");
	if (!f) {
		fprintf(stderr, "Could not open the listing output file '%s'\n", fname);
		exit(-1);
	}

	for (z = x = 0; z < state->prog_size && x < MAX_PROG_SIZE; x++) {
		if (state->program[x].line_number != -1) {
			++z;
			if (state->program[x].label[0]) {
				fprintf(f, "[%-15s ", state->program[x].label);
			} else {
				fprintf(f, "[%16s", "");
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
			fprintf(f, "0x%04X]: 0x%04X ; %-20s (%s:%d)\n", x*2, state->program[x].opcode, linebuf, state->program[x].fname, state->program[x].line_number);
		}
	}
	fclose(f);
}

int main(int argc, char **argv)
{
	int i;
	struct compiler_state *state;
	char *libdir = "lib/";
	char *missing_symbol = NULL;
	
	state = calloc(1, sizeof *state);
	state->prog_size    = 4096;				// default to 8KB programs
	state->line_number  = 1;
	
	for (i = 0; i < MAX_PROG_SIZE; i++) {
		state->program[i].opcode = 0x0000;
		state->program[i].line_number = -1;
	}
	state->reg_idx = 1;
	
	// options pass
	for (i = 0; i < argc; i++) {
		if (!strcmp(argv[i], "--lib")) {
			if (i + 1 < argc) {
				libdir = argv[i+1];
				++i;
			} else {
				fprintf(stderr, "--lib requires a parameter\n");
				exit(-1);
			}
		} else if (!strcmp(argv[i], "--define")) {
			if (i + 2 < argc) {
				char line[512];
				sprintf(line, "%s %s", argv[i+1], argv[i+2]);
				insert_symbol(state, line, 0);
				i += 2;
			} else {
				fprintf(stderr, "--define requires two parameters\n");
				exit(-1);
			}
		}
	}
	
	// assemble files pass
	for (i = 0; i < argc; i++) {
		char *s = strstr(argv[i], ".s");
		if (s && s[2] == 0) { 
			// .s file so compile it
			compile_file(state, argv[i]);
		}
	}
	
	// linking pass
	missing_symbol = NULL;
	while (resolve_labels(state, &missing_symbol) != 0) {
		if (link(state, libdir, missing_symbol) < 0) {
			fprintf(stderr, "Could not link in symbol '%s'\n", missing_symbol);
			exit(-1);
		}
	}
	
	// determine memory usage
	{
		int y = 0;
		for (i = 0; i < MAX_PROG_SIZE; i++) {
			if (state->program[i].line_number != -1) {
				++y;
			}
		}
		printf("Used %d (%d %%) of %d words.\n", y, (y * 100) / state->prog_size, state->prog_size);
	}

	for (i = 0; i < argc; i++) {
		if (!strcmp(argv[i], "--hex")) {
			if (i + 1 < argc) {
				emit_hexfile(state, argv[i+1]);
				++i;
			} else {
				fprintf(stderr, "--hex requires a parameter\n");
				exit(-1);
			}
		} else if (!strcmp(argv[i], "--bin")) {
			if (i + 1 < argc) {
				emit_binfile(state, argv[i+1]);
				++i;
			} else {
				fprintf(stderr, "--bin requires a parameter\n");
				exit(-1);
			}
		} else if (!strcmp(argv[i], "--rom")) {
			if (i + 1 < argc) {
				emit_romfile(state, argv[i+1]);
				++i;
			} else {
				fprintf(stderr, "--rom requires a parameter\n");
				exit(-1);
			}
		} else if (!strcmp(argv[i], "--mon")) {
			if (i + 1 < argc) {
				emit_monfile(state, argv[i+1]);
				++i;
			} else {
				fprintf(stderr, "--mon requires a parameter\n");
				exit(-1);
			}
		} else if (!strcmp(argv[i], "--list")) {
			if (i + 1 < argc) {
				emit_lstfile(state, argv[i+1]);
				++i;
			} else {
				fprintf(stderr, "--list requires a parameter\n");
				exit(-1);
			}
		}
	}
	return 0;
}
