#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdio.h>
#include <ctype.h>

// 
#define MAX_SYMBOLS 2048

// opcode classes
#define OP_CLASS_ALU 0      // opcodes that take 1+ sources, and 1 dest (upto SWA)

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
    { "MOV", OP_CLASS_ALU, 0, 0b00000, 0, 0 }, // MOV
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

static void skip_whitespace(char **p)
{
    while (**p == ' ' || **p == '\t') {
        ++(*p);
    }
}

static int expect(char **p, char c)
{
    if (**p == c) {
        ++(*p);
        return 1;
    }
    return 0;
}

static int matchcase(char **p, char *s)
{
    if (!strncasecmp(*p, s, strlen(s))) {
        *(p) += strlen(s);
        return 1;
    }
    return 0;
}

static void error(char *msg, const char *p)
{
    fprintf(stderr, "ERROR: %s:%u\n", state.file_name, state.line_num);
    fprintf(stderr, "ERROR: %s\n", msg);
    fprintf(stderr, "ERROR: Rest of line '%s'\n", p);
}

static char *read_symbol(char **p)
{
    char buf[512];
    int x;

    memset(buf, 0, sizeof buf);
    x = 0;
    skip_whitespace(p);
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

static uint32_t match_symbol(char **p)
{
    char *tmp, *sym;
    uint32_t x;

    // parse in symbol to read
    tmp = *p;
    sym = read_symbol(&tmp);

    for (x = 0; x < MAX_SYMBOLS; x++) {
        if (symbols[x].symbol && !strcasecmp(symbols[x].symbol, sym)) {
            free(sym);
            *p = tmp;
            return x;
        }
    }
    free(sym);
    return 0xFFFFFFFF;
}

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

static uint32_t to_oper(char **p)
{
    uint32_t ret = 0;
    skip_whitespace(p);
    if (expect(p, '(')) {
        // memory at ...
        skip_whitespace(p);
        if ((ret = match_symbol(p)) != 0xFFFFFFFF) {
            ret = (symbols[ret].value << 4) | 0b1111;
        } else if (expect(p, 'A')) {
            ret = 0b1000;
        } else if (expect(p, 'B')) {
            ret = 0b1001;
        } else if (expect(p, 'C')) {
            ret = 0b1010;
        } else if (expect(p, 'D')) {
            ret = 0b1011;
        } else if (expect(p, 'E')) {
            ret = 0b1100;
        } else if (expect(p, 'F')) {
            ret = 0b1101;
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
    if ((ret = match_symbol(p)) != 0xFFFFFFFF) {
        ret = (symbols[ret].value << 4) | 0b0111;
    } else if (expect(p, 'A')) {
        ret = 0b0000;
    } else if (expect(p, 'B')) {
        ret = 0b0001;
    } else if (expect(p, 'C')) {
        ret = 0b0010;
    } else if (expect(p, 'D')) {
        ret = 0b0011;
    } else if (expect(p, 'E')) {
        ret = 0b0100;
    } else if (expect(p, 'F')) {
        ret = 0b0101;
    } else if (matchcase(p, "PC")) {
        ret = 0b0110;
    } else if (matchcase(p, "S1")) {
        ret = 0b1110;
    } else {
        ret = (read_num(p) << 4) | 0b0111;
    }
    return ret;
}

static void compile(char *filename);

static void handle_label_def(void)
{
    uint32_t x;

    // find empty slot
    for (x = 0; x < MAX_SYMBOLS; x++) {
        if (!symbols[x].symbol) {
            symbols[x].symbol = read_symbol(&state.curp);
            if (!expect(&state.curp, ':')) {
                error("Missing : from label definition", state.curp);
            }
            symbols[x].value  = state.PC;
            return;
        }
    }
    error("Symbol table is full.", state.curp);
}

static void handle_equate(void)
{
    uint32_t x;

    // find empty slot
    for (x = 0; x < MAX_SYMBOLS; x++) {
        if (!symbols[x].symbol) {
            symbols[x].symbol = read_symbol(&state.curp);
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

// opcodes of the form OP SSSS[,A] > DDDD
// by time we get here we're past OP
static void handle_alu_opcode(uint32_t op_index)
{
    // parse in the opcode
    skip_whitespace(&state.curp);
    program[state.PC].active = 1;
    program[state.PC].oper5 = opcodes[op_index].oper5;
    program[state.PC].s4    = to_oper(&state.curp);
    if (expect(&state.curp, ',')) {
        skip_whitespace(&state.curp);
        if (!expect(&state.curp, 'A')) {
            error("Syntax error.", state.curp);
        }
    }
    skip_whitespace(&state.curp);
    if (!expect(&state.curp, '>')) {
        error("Syntax error.", state.curp);
    }
    skip_whitespace(&state.curp);
    program[state.PC].d4 = to_oper(&state.curp);

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
            }
        }
    }
    error("Syntax error did not match any opcodes.", state.curp);
}

static void process_line(void)
{
    skip_whitespace(&state.curp);
    if (matchcase(&state.curp, ".org")) {
        // handle .org
        state.PC = read_num(&state.curp);
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
        process_line();
    }
    fclose(state.curfile);
    state.curfile   = prev.prevfile;
    state.file_name = prev.prevfname;
    state.line_num  = prev.prevlinenum;
}


int main(int argc, char **argv)
{
    memset(&state, 0, sizeof state);
    memset(&program, 0, sizeof program);
    memset(&symbols, 0, sizeof symbols);
    if (argc == 1) {
        fprintf(stderr, "TurbineAsm filename\n");
        return 0;
    }
    compile(argv[1]);
    uint32_t x, y;
    for (x = 0; x < 65536;) {
        if (program[x].active) {
            for (y = 0; y < program[x].num_words; y++) {
                printf("PC[%04x] == %04"PRIx16"", x+y, program[x+y].word);
                if (y == 0) {
                    printf(", %s:%d, %s", program[x+y].source.file_name, program[x+y].source.lineno, program[x+y].source.source_line);
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