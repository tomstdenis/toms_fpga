#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdio.h>
#include <ctype.h>

// if you have 2K symbols you've made life mistakes
#define MAX_SYMBOLS 2048

// opcode classes
#define OP_CLASS_ALU  0      // opcodes that take 1+ sources, and 1 dest (upto SWA)
#define OP_CLASS_FLAG 1      // opcodes that take 0 operands (flags)
#define OP_CLASS_1OP  2      // opcodes that take 1 sources, and 0 dest
#define OP_CLASS_BCHK 3      // bit check

// this table represents all of the valid instructions (not in all permutations)
static const struct opcode {
    char *name;
    uint32_t
        opcode_class;       // class type this allows similar opcodes to be handled together
    uint32_t
        c3,                 // CCC bits
        oper5,              // OOOOO bits
        s4,                 // SSSS bits
        d4;                 // DDDD bits
} opcodes[] = {
    { "MOV",  OP_CLASS_ALU, 0, 0b00000, 0, 0 }, // MOV
    { "iMOV", OP_CLASS_ALU, 0, 0b00001, 0, 0 }, // iMOV
    { "ADD",  OP_CLASS_ALU, 0, 0b00010, 0, 0 }, // ADD
    { "iADD", OP_CLASS_ALU, 0, 0b00011, 0, 0 }, // iADD
    { "ADC",  OP_CLASS_ALU, 0, 0b00100, 0, 0 }, // ADC
    { "SUB",  OP_CLASS_ALU, 0, 0b00101, 0, 0 }, // SUB
    { "iSUB", OP_CLASS_ALU, 0, 0b00110, 0, 0 }, // iSUB
    { "SBC",  OP_CLASS_ALU, 0, 0b00111, 0, 0 }, // SBC
    { "INC",  OP_CLASS_ALU, 0, 0b01000, 0, 0 }, // INC
    { "iINC", OP_CLASS_ALU, 0, 0b01001, 0, 0 }, // iINC
    { "DEC",  OP_CLASS_ALU, 0, 0b01010, 0, 0 }, // DEC
    { "iDEC", OP_CLASS_ALU, 0, 0b01011, 0, 0 }, // iDEC
    { "NEG",  OP_CLASS_ALU, 0, 0b01100, 0, 0 }, // NEG
    { "iNEG", OP_CLASS_ALU, 0, 0b01101, 0, 0 }, // iNEG
    { "NOT",  OP_CLASS_ALU, 0, 0b01110, 0, 0 }, // NOT
    { "AND",  OP_CLASS_ALU, 0, 0b01111, 0, 0 }, // AND
    { "NAND", OP_CLASS_ALU, 0, 0b10000, 0, 0 }, // NAND
    { "OR",   OP_CLASS_ALU, 0, 0b10001, 0, 0 }, // OR
    { "NOR",  OP_CLASS_ALU, 0, 0b10010, 0, 0 }, // NOR
    { "XOR",  OP_CLASS_ALU, 0, 0b10011, 0, 0 }, // XOR
    { "XNOR", OP_CLASS_ALU, 0, 0b10100, 0, 0 }, // XNOR
    { "SHL",  OP_CLASS_ALU, 0, 0b10101, 0, 0 }, // SHL
    { "iSHL", OP_CLASS_ALU, 0, 0b10110, 0, 0 }, // iSHL
    { "SLC",  OP_CLASS_ALU, 0, 0b10111, 0, 0 }, // SLC
    { "SHR",  OP_CLASS_ALU, 0, 0b11000, 0, 0 }, // SHR
    { "SRC",  OP_CLASS_ALU, 0, 0b11001, 0, 0 }, // SRC
    { "ASR",  OP_CLASS_ALU, 0, 0b11010, 0, 0 }, // ASR
    { "iASR", OP_CLASS_ALU, 0, 0b11011, 0, 0 }, // iASR
    { "ROL",  OP_CLASS_ALU, 0, 0b11100, 0, 0 }, // ROL
    { "ROR",  OP_CLASS_ALU, 0, 0b11101, 0, 0 }, // ROR
    { "MIR",  OP_CLASS_ALU, 0, 0b11110, 0, 0 }, // MIR
    { "SWA",  OP_CLASS_ALU, 0, 0b11111, 0, 0 }, // SWA
    // flag operations and 0 operand opcodes
    { "SETZ", OP_CLASS_FLAG, 0, 0b00001, 0b0111, 0b0111 }, // SETZ
    { "CLRZ", OP_CLASS_FLAG, 0, 0b00011, 0b0111, 0b0111 }, // SCLRZ
    { "SETC", OP_CLASS_FLAG, 0, 0b00101, 0b0111, 0b0111 }, // SETC
    { "CLRC", OP_CLASS_FLAG, 0, 0b00111, 0b0111, 0b0111 }, // CLRC
    { "INVZ", OP_CLASS_FLAG, 0, 0b01001, 0b0111, 0b0111 }, // INVZ
    { "INVC", OP_CLASS_FLAG, 0, 0b01011, 0b0111, 0b0111 }, // INVC
    { "SETI", OP_CLASS_FLAG, 0, 0b01101, 0b0111, 0b0111 }, // SETI
    { "CLRI", OP_CLASS_FLAG, 0, 0b01111, 0b0111, 0b0111 }, // CLRI
    { "RETI", OP_CLASS_FLAG, 0, 0b01001, 0b0000, 0b0111 }, // RETI
    { "SVST", OP_CLASS_FLAG, 0, 0b01011, 0b0000, 0b0111 }, // SVST
    { "LDST", OP_CLASS_FLAG, 0, 0b01101, 0b0000, 0b0111 }, // LDST
    { "SWST", OP_CLASS_FLAG, 0, 0b01111, 0b0000, 0b0111 }, // SWST

    // 1 operand opcodes
    { "CMP",  OP_CLASS_1OP,  0, 0b01010, 0b0000, 0b0111 }, // CMP
    { "JSR",  OP_CLASS_1OP,  0, 0b01000, 0b0000, 0b0111 }, // JSR
    { "BCHK", OP_CLASS_BCHK, 0, 0b10000, 0b0000, 0b0111 }, // BCHK
    // 1 operand opcodes that are cleaner versions of the originals
    { "PUSH2",OP_CLASS_1OP,   0, 0b00100, 0b0000, 0b0111 }, // PUSH2 (MOV SRC > SP2)
    { "POP2", OP_CLASS_1OP,   0, 0b00101, 0b0000, 0b0111 }, // POP2 (MOV SP2 > DST)
    { "STSP", OP_CLASS_1OP,   0, 0b00000, 0b0000, 0b0111 }, // STSP (MOV SRC,SP)
    { "LDSP", OP_CLASS_1OP,   0, 0b00001, 0b0000, 0b0111 }, // LDSP (MOV SP,SRC)
    { "OUT",  OP_CLASS_1OP,   0, 0b00010, 0b0000, 0b0111 }, // OUT (MOV SRC >IO)
    { "IN",   OP_CLASS_1OP,   0, 0b00011, 0b0000, 0b0111 }, // IN (MOV IO >DST)
    { "NDXS", OP_CLASS_1OP,   0, 0b01100, 0b0000, 0b0111 }, // NDXS
    { "NDXD", OP_CLASS_1OP,   0, 0b01110, 0b0000, 0b0111 }, // NDXD
    { "WRSTAT", OP_CLASS_1OP, 0, 0b00110, 0b0000, 0b0111 }, // WRSTAT (MOV SRC > STAT)
    { "RDSTAT", OP_CLASS_1OP, 0, 0b00111, 0b0000, 0b0111 }, // RDSTAT (MOV STAT > DST)
    { NULL,             0, 0,       0, 0, 0 }  // end of list
};

// this array represents every possible 16-bit location
static struct {
    struct opcode *oper;    // which table entry for this opcode
    struct {
        char *file_name;
        char *source_line;
        uint32_t lineno;
    } source;
    uint32_t
        active,
        cond_code,
        oper5,
        s4,
        d4,
        num_words;
    uint16_t
        word;    
} program[65536];

static struct {
    char *symbol;
    uint32_t value;
} symbols[MAX_SYMBOLS];

static struct {
    FILE *curfile;
    char *file_name;
    uint32_t line_num;
    char curline[512], *curp;
    uint32_t PC;
} state;

// skip spaces and tabs
static void skip_whitespace(char **p)
{
    while (**p == ' ' || **p == '\t') {
        ++(*p);
    }
}

// if we match the next symbol advance the string (return 1), otherwise stay put and return 0
static int expect(char **p, char c)
{
    if (**p == c) {
        ++(*p);
        return 1;
    }
    return 0;
}

// like expect but for strings and not case sensitive
static int matchcase(char **p, char *s)
{
    if (!strncasecmp(*p, s, strlen(s))) {
        *(p) += strlen(s);
        return 1;
    }
    return 0;
}

// error out
static void error(char *msg, const char *p)
{
    fprintf(stderr, "ERROR: %s:%u\n", state.file_name, state.line_num);
    fprintf(stderr, "ERROR: %s\n", msg);
    fprintf(stderr, "ERROR: Rest of line '%s'\n", p);
    exit(-1);
}

// read a symbol from the stream or return NULL if (aside from whitespace) we're not at a symbol
static char *read_symbol(char **p)
{
    char buf[512];
    int x;

    memset(buf, 0, sizeof buf);
    x = 0;
    skip_whitespace(p);

    // valid symbols start with a letter or _
    if (!(isalpha(**p) || **p == '_')) {
        return NULL;
    }

    // parse it in
    for (;;) {
        if ((x && isdigit(**p)) || isalpha(**p) || **p == '_') {
            buf[x++] = **p;
            ++(*p);
        } else {
            break;
        }
    }
    skip_whitespace(p);
    return strdup(buf);
}

// match a symbol, if not found add it, if not symbol return 0xFFFFFFFF
static uint32_t match_symbol(char **p)
{
    char *tmp, *sym;
    uint32_t x;

    // parse in symbol to read
    tmp = *p;
    sym = read_symbol(&tmp);
    if (!sym) {
        return 0xFFFFFFFF;
    }
    for (x = 0; x < MAX_SYMBOLS; x++) {
        if (symbols[x].symbol && !strcasecmp(symbols[x].symbol, sym)) {
            free(sym);
            *p = tmp;
            return x;
        }
    }
    // symbol not found so let's add it 
    for (x = 0; x < MAX_SYMBOLS; x++) {
        if (!symbols[x].symbol) {
            symbols[x].symbol = strdup(sym);
            symbols[x].value  = 0x00010000;
            free(sym);
            *p = tmp;
            return x;
        }
    }
    error("Out of symbol space for a new symbol", state.curp);
    return 0;
}

// read $hex, %bin, or dec number
static uint32_t read_num(char **p)
{
    uint32_t ret;
    skip_whitespace(p);
    ret = 0;
    if (expect(p, '$')) {
        // hex num
        for(;;) {
            char c = toupper(**p); ++(*p);
            if (c >= '0' && c <= '9') {
                ret <<= 4;
                ret |= (c - '0');
            } else if (c >= 'A' && c <= 'F') {
                ret <<= 4;
                ret |= (10 + (c - 'A'));
            } else {
                --(*p);
                break;
            }
        }
    } else if (expect(p, '%')) {
        // bin num
        for (;;) {
            char c = toupper(**p); ++(*p);
            if (c >= '0' && c <= '1') {
                ret <<= 1;
                ret |= (c - '0');
            } else {
                --(*p);
                break;
            }
        }
    } else if (isdigit(**p)) {
        // decimal
        for(;;) {
            char c = **p; ++(*p);
            if (c >= '0' && c <= '9') {
                ret *= 10;
                ret += (c - '0');
            } else {
                --(*p);
                break;
            }
        }
    } else {
        // symbol
        ret = match_symbol(p);
        if (ret != 0xFFFFFFFF) {
            ret = symbols[ret].value;
        } else {
            error("Syntax error.", *p);
            return 0;
        }
    }
    return ret;
}

// parse a conditional code
static uint32_t to_cond(char **p)
{
    uint32_t ret;
    skip_whitespace(p);
    if (expect(p, '(')) {
        skip_whitespace(p);
        if (matchcase(p, "Z AND C")) {
            ret = 0b100;
        } else if (matchcase(p, "Z OR C")) {
            ret = 0b101;
        } else if (matchcase(p, "Z XOR C")) {
            ret = 0b110;
        } else if (matchcase(p, "Z")) {
            ret = 0b000;
        } else if (matchcase(p, "!Z")) {
            ret = 0b001;
        } else if (matchcase(p, "C")) {
            ret = 0b010;
        } else if (matchcase(p, "!C")) {
            ret = 0b011;
        } else {
            error("Unknown conditional code", *p);
            return 0;
        }
        skip_whitespace(p);
        if (expect(p, ')')) {
            return ret;
        }
        error("Missing closing parenthesis for conditional code", *p);
        return 0;
    }
    // default is always
    return 0b111;
}

// parse a operand.  Bits [3:0] are the oper code and [19:4] are the value if immediate
static uint32_t to_oper(char **p)
{
    char *tmp, *sym;
    uint32_t ret = 0;
    skip_whitespace(p);
    if (expect(p, '(')) {
        // memory at ...
        skip_whitespace(p);
        tmp = *p;
        sym = read_symbol(&tmp);
        if (sym && !strcmp(sym, "NDX")) {
            *p = tmp;
            skip_whitespace(p);
            free(sym);
            if (expect(p, '+') == 0) {
                error("Syntax error: expected a '+' after NDX", state.curp);
            }
            skip_whitespace(p);
            tmp = *p;
            sym = read_symbol(&tmp);
        }
        if (sym) {
            if (!strcmp(sym, "A")) {
                ret = 0b1000;
                *p = tmp;
            } else if (!strcmp(sym, "B")) {
                ret = 0b1001;
                *p = tmp;
            } else if (!strcmp(sym, "C")) {
                ret = 0b1010;
                *p = tmp;
            } else if (!strcmp(sym, "D")) {
                ret = 0b1011;
                *p = tmp;
            } else if (!strcmp(sym, "E")) {
                ret = 0b1100;
                *p = tmp;
            } else if (!strcmp(sym, "F")) {
                ret = 0b1101;
                *p = tmp;
            } else if ((ret = match_symbol(p)) != 0xFFFFFFFF) {
                ret = (symbols[ret].value << 4) | 0b1111;
            }
            free(sym);
        } else {
            ret = (read_num(p) << 4) | 0b1111;
        }
        skip_whitespace(p);
        if (!expect(p, ')')) {
            error("Syntax error was exppecting ')'", *p);
            return 0xFFFFFFFF;
        }
        return ret;
    }
    tmp = *p;
    sym = read_symbol(&tmp);
    if (sym) {
        if (!strcmp(sym, "A")) {
            ret = 0b0000;
            *p = tmp;
        } else if (!strcmp(sym, "B")) {
            ret = 0b0001;
            *p = tmp;
        } else if (!strcmp(sym, "C")) {
            ret = 0b0010;
            *p = tmp;
        } else if (!strcmp(sym, "D")) {
            ret = 0b0011;
            *p = tmp;
        } else if (!strcmp(sym, "E")) {
            ret = 0b0100;
            *p = tmp;
        } else if (!strcmp(sym, "F")) {
            ret = 0b0101;
            *p = tmp;
        } else if (!strcmp(sym, "PC")) {
            ret = 0b0110;
            *p = tmp;
        } else if (!strcmp(sym, "S1")) {
            ret = 0b1110;
            *p = tmp;
        } else if ((ret = match_symbol(p)) != 0xFFFFFFFF) {
            ret = (symbols[ret].value << 4) | 0b0111;
        }
        free(sym);
    } else {
        ret = (read_num(p) << 4) | 0b0111;
    }
    return ret;
}

static void compile(char *filename);

// handle a label definition which is a symbol and a ':'
static void handle_label_def(void)
{
    uint32_t x;
    char *sym;

    sym = read_symbol(&state.curp);
    if (!sym) {
        error("Syntax error: expected a symbol", state.curp);
    }

    // find empty slot
    for (x = 0; x < MAX_SYMBOLS; x++) {
        if (!symbols[x].symbol || !strcmp(symbols[x].symbol, sym)) {
            if (!symbols[x].symbol) {
                symbols[x].symbol = sym;
            } else {
                free(sym);
            }
            if (!expect(&state.curp, ':')) {
                error("Missing : from label definition", state.curp);
            }
            symbols[x].value  = state.PC;
            return;
        }
    }
    error("Symbol table is full.", state.curp);
}

// handle an equate, which is a symbol, '=', and a symbol or literal
static void handle_equate(void)
{
    uint32_t x;
    char *sym;

    sym = read_symbol(&state.curp);
    if (!sym) {
        error("Syntax error: expecting a symbol", state.curp);
    }

    // find empty slot
    for (x = 0; x < MAX_SYMBOLS; x++) {
        if (!symbols[x].symbol || !strcmp(symbols[x].symbol, sym)) {
            if (!symbols[x].symbol) {
                symbols[x].symbol = sym;
            } else {
                free(sym);
            }
            if (expect(&state.curp, '=')) {
                symbols[x].value  = read_num(&state.curp);
            } else {
                error("Expecting an '='.", state.curp);
            }
            return;
        }
    }
    error("Symbol table is full.", state.curp);
}

// opcodes of the form OP SSSS,BIT
// by time we get here we're past OP
static void handle_bchk_opcode(uint32_t op_index)
{
    // parse in the opcode
    skip_whitespace(&state.curp);
    program[state.PC].active = 1;
    program[state.PC].oper5 = opcodes[op_index].oper5;
    program[state.PC].s4    = to_oper(&state.curp);
    program[state.PC].d4    = opcodes[op_index].d4;
    skip_whitespace(&state.curp);
    if (expect(&state.curp, ',')) {
        skip_whitespace(&state.curp);
        program[state.PC].oper5 |= read_num(&state.curp) & 15;
    }

    // now render it out to 1-2 words
    // CCC OOOOO SSSS DDDD
    program[state.PC].word = 
        (program[state.PC].cond_code << (4+4+5)) |
        (program[state.PC].oper5 << (4+4)) |
        ((program[state.PC].s4 & 15) << 4) |
        ((program[state.PC].d4 & 15));

    uint32_t i = state.PC++;
    if ((program[i].s4 & 0b0111) == 0b0111) {
        // immediate type
        program[i].num_words += 1;
        if (program[state.PC].active) {
            error("This PC is already occupied.", state.curp);
        }
        program[state.PC++].word = program[i].s4 >> 4;
    }
}

// opcodes of the form OP SSSS[,A] > DDDD
// by time we get here we're past OP
static void handle_1op_opcode(uint32_t op_index)
{
    // parse in the opcode
    skip_whitespace(&state.curp);
    program[state.PC].active = 1;
    program[state.PC].oper5 = opcodes[op_index].oper5;
    program[state.PC].s4    = to_oper(&state.curp);
    skip_whitespace(&state.curp);
    if (expect(&state.curp, ',')) {
        skip_whitespace(&state.curp);
        if (!expect(&state.curp, 'A')) {
            error("Syntax error: 'A' must follow ',' as ALU 2nd source (or omit ,A).", state.curp);
        }
    }
    program[state.PC].d4 = opcodes[op_index].d4;

    // now render it out to 1-2 words
    // CCC OOOOO SSSS DDDD
    program[state.PC].word = 
        (program[state.PC].cond_code << (4+4+5)) |
        (program[state.PC].oper5 << (4+4)) |
        ((program[state.PC].s4 & 15) << 4) |
        ((program[state.PC].d4 & 15));

    uint32_t i = state.PC++;
    if ((program[i].s4 & 0b0111) == 0b0111) {
        // immediate type
        program[i].num_words += 1;
        if (program[state.PC].active) {
            error("This PC is already occupied.", state.curp);
        }
        program[state.PC++].word = program[i].s4 >> 4;
    }
}

// opcodes of the form OP
static void handle_flag_opcode(uint32_t op_index)
{
    // parse in the opcode
    program[state.PC].active = 1;
    program[state.PC].oper5 = opcodes[op_index].oper5;
    program[state.PC].s4 = opcodes[op_index].d4;
    program[state.PC].d4 = opcodes[op_index].s4;

    // now render it out to 1-3 words
    // CCC OOOOO SSSS DDDD
    program[state.PC].word = 
        (program[state.PC].cond_code << (4+4+5)) |
        (program[state.PC].oper5 << (4+4)) |
        ((program[state.PC].s4 & 15) << 4) |
        ((program[state.PC].d4 & 15));
    ++(state.PC);
}

// opcodes of the form OP SSSS[,A] > DDDD
// by time we get here we're past OP
static void handle_alu_opcode(uint32_t op_index)
{
    // parse in the opcode
    skip_whitespace(&state.curp);
    program[state.PC].active = 1;
    program[state.PC].oper5 = opcodes[op_index].oper5;
    program[state.PC].s4    = to_oper(&state.curp);
    skip_whitespace(&state.curp);
    if (expect(&state.curp, ',')) {
        skip_whitespace(&state.curp);
        if (!expect(&state.curp, 'A')) {
            error("Syntax error: 'A' must follow ',' as ALU 2nd source (or omit ,A).", state.curp);
        }
    }
    skip_whitespace(&state.curp);
    if (!expect(&state.curp, '>')) {
        error("Syntax error: expecting destination token '>'.", state.curp);
    }
    skip_whitespace(&state.curp);
    program[state.PC].d4 = to_oper(&state.curp);

    if ((program[state.PC].d4 & 15) == 0b0111) {
        error("Syntax error: Destination cannot be a literal.", state.curp);
    }

    // now render it out to 1-3 words
    // CCC OOOOO SSSS DDDD
    program[state.PC].word = 
        (program[state.PC].cond_code << (4+4+5)) |
        (program[state.PC].oper5 << (4+4)) |
        ((program[state.PC].s4 & 15) << 4) |
        ((program[state.PC].d4 & 15));

    uint32_t i = state.PC++;
    if ((program[i].s4 & 0b0111) == 0b0111) {
        // immediate type
        program[i].num_words += 1;
        if (program[state.PC].active) {
            error("This PC is already occupied.", state.curp);
        }
        program[state.PC++].word = program[i].s4 >> 4;
    }
    if ((program[i].d4 & 0b0111) == 0b0111) {
        // immediate type
        program[i].num_words += 1;
        if (program[state.PC].active) {
            error("This PC is already occupied.", state.curp);
        }
        program[state.PC++].word = program[i].d4 >> 4;
    }
}

static void handle_opcode(void)
{
    uint32_t x;

    if (program[state.PC].active) {
        error("This PC is already occupied.", state.curp);
    }
    program[state.PC].source.file_name   = strdup(state.file_name);
    program[state.PC].source.source_line = strdup(state.curline);
    program[state.PC].source.lineno      = state.line_num;
    program[state.PC].num_words          = 1;
    program[state.PC].cond_code          = to_cond(&state.curp);
    skip_whitespace(&state.curp);
    for (x = 0; opcodes[x].name; x++) {
        if (matchcase(&state.curp, opcodes[x].name)) {
            // match opcode name
            if (opcodes[x].opcode_class == OP_CLASS_ALU) {
                handle_alu_opcode(x);
                return;
            } else if (opcodes[x].opcode_class == OP_CLASS_BCHK) {
                handle_bchk_opcode(x);
                return;
            } else if (opcodes[x].opcode_class == OP_CLASS_1OP) {
                handle_1op_opcode(x);
                return;
            } else if (opcodes[x].opcode_class == OP_CLASS_FLAG) {
                handle_flag_opcode(x);
                return;
            }
        }
    }
    error("Syntax error did not match any opcodes.", state.curp);
}

void handle_include(void)
{
    char buf[512];
    uint32_t x;

    memset(&buf, 0, sizeof buf);
    x = 0;
    skip_whitespace(&state.curp);
    while (isalnum(state.curp[0]) || state.curp[0] == '.' || state.curp[0] == '/') {
        buf[x++] = *(state.curp++);
    }
    compile(buf);
}

static void process_line(void)
{
    skip_whitespace(&state.curp);
    if (matchcase(&state.curp, ".org")) {
        // handle .org
        state.PC = read_num(&state.curp);
    } else if (matchcase(&state.curp, ".word")) {
        // handle .word
        if (program[state.PC].active == 0) {
            program[state.PC].active             = 1;
            program[state.PC].word               = read_num(&state.curp);
            program[state.PC].source.file_name   = strdup(state.file_name);
            program[state.PC].source.source_line = strdup(state.curline);
            program[state.PC].source.lineno      = state.line_num;
            program[state.PC].num_words          = 1;
            ++(state.PC);
        } else {
            error("Syntax error: This address is already populated", state.curp);
        }
    } else if (matchcase(&state.curp, ".include")) {
        handle_include();
    } else if (strchr(state.curp, ':')) {
        handle_label_def();
    } else if (strchr(state.curp, '=')) {
        handle_equate();
    } else {
        handle_opcode();
    }
}

static void compile(char *filename)
{
    struct {
        FILE *prevfile;
        char *prevfname;
        uint32_t prevlinenum;
    } prev;

    prev.prevfile    = state.curfile;
    prev.prevfname   = state.file_name;
    prev.prevlinenum = state.line_num;

    state.file_name  = filename;
    state.curfile = fopen(filename, "r");
    if (!state.curfile) {
        error("Could not open file.\n", filename);
        return;
    }
    state.line_num = 0;
    while (fgets(state.curline, sizeof(state.curline)-1, state.curfile)) {
        state.curp = &state.curline[0];
        ++(state.line_num);

        // cut off comments
        uint32_t x;
        for (x = 0; state.curline[x]; x++) {
            if (state.curline[x] == ';' || state.curline[x] == '\r' || state.curline[x] == '\n') {
                state.curline[x] = 0;
                break;
            }
        }

        skip_whitespace(&state.curp);
        if (!(state.curp[0] == '\r' || state.curp[0] == '\n' || state.curp[0] == 0)) {
            process_line();
        }
    }
    fclose(state.curfile);
    state.curfile   = prev.prevfile;
    state.file_name = prev.prevfname;
    state.line_num  = prev.prevlinenum;
}

static void fixups(void)
{
    uint32_t x;
    for (x = 0; x < 65536; x++) {
        program[x].active = 0;
    }
}

int main(int argc, char **argv)
{
    uint32_t x, y, passes, fail;

    memset(&state, 0, sizeof state);
    memset(&program, 0, sizeof program);
    memset(&symbols, 0, sizeof symbols);
    if (argc == 1) {
        fprintf(stderr, "TurbineAsm filename\n");
        return 0;
    }
    for (passes = 0; passes < 8; passes++) {
        fixups();
        compile(argv[1]);
    }
    for (fail = x = 0; x < MAX_SYMBOLS; x++) {
        if (symbols[x].symbol) {
            if (symbols[x].value & 0x10000) {
                fprintf(stderr, "error: missing symbol [%s]\n", symbols[x].symbol);
                fail = 1;
            }
        }
    }
    if (fail) {
        fprintf(stderr, "error: There were unresolved symbols.\n");
        exit(1);
    }

    for (x = 0; x < 65536;) {
        if (program[x].active) {
            for (y = 0; y < program[x].num_words; y++) {
                printf("PC[%04x] == %04"PRIx16"", x+y, program[x+y].word);
                if (y == 0) {
                    printf(", %s:%d, %s\n", program[x+y].source.file_name, program[x+y].source.lineno, program[x+y].source.source_line);
                } else {
                    printf("\n");
                }
            }
            x += y;
        } else {
            ++x;
        }
    }
}