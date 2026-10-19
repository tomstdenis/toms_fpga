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
        cond_code,
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
    if (!strcasecmp(*p, s)) {
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

uint32_t to_cond(char **p)
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

static uint32_t read_num(char **p)
{
    uint32_t ret;
    skip_whitespace(p);
    ret = 0;
    if (expect(p, '$')) {
        // hex num
        for(;;) {
            char c = toupper(**p); ++(*p);
            ret <<= 4;
            if (c >= '0' && c <= '9') {
                ret |= (c - '0');
            } else if (c >= 'A' && c <= 'F') {
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
            ret <<= 1;
            if (c >= '0' && c <= '1') {
                ret |= (c - '0');
            } else {
                --(*p);
                break;
            }
        }
    } else {
        // decimal
        for(;;) {
            char c = toupper(**p); ++(*p);
            ret *= 10;
            if (c >= '0' && c <= '9') {
                ret |= (c - '0');
            } else {
                --(*p);
                break;
            }
        }
    }
    return ret;
}

char *read_symbol(char **p)
{
    char buf[512];
    int x;

    memset(buf, 0, sizeof buf);
    x = 0;
    for (;;) {
        if ((x && isdigit(**p)) || isalpha(**p) || **p == '_') {
            buf[x++] = **p;
        } else {
            break;
        }
    }
    skip_whitespace(p);
    if (!expect(p, ':')) {
        error("Missing : from label definition", *p);
    }
    return strdup(buf);
}

static void compile(const char *filename);

static void handle_label_def(void)
{
    uint32_t x;

    // find empty slot
    for (x = 0; x < MAX_SYMBOLS; x++) {
        if (symbols[x].symbol) {
            symbols[x].symbol = read_symbol(&state.curp);
            symbols[x].value  = state.PC;
            return;
        }
    }
    error("Symbol table is full.", "");
}

// opcodes of the form OP SSSS[,A] > DDDD
static void handle_alu_opcode(uint32_t op_index)
{
}

static void handle_opcode(void)
{
    uint32_t x;

    program[state.PC].cond_code = to_cond(&state.curp);
    for (x = 0; opcodes[x].name; x++) {
        if (matchcase(&state.curp, opcodes[x].name)) {
            // match opcode name
            if (opcodes[x].opcode_class == OP_CLASS_ALU) {
                handle_alu_opcode(x);
            }
        }
    }
    error("Syntax error.", state.curp);
}

static void process_line(void)
{
    skip_whitespace(&state.curp);
    if (matchcase(&state.curp, ".org")) {
        // handle .org
        state.PC = read_num(&state.curp);
    } else if (!strchr(state.curp, ':')) {
        handle_label_def();
    } else {
        handle_opcode();
    }
}

static void compile(const char *filename)
{
    struct {
        FILE *prevfile;
        uint32_t prevlinenum;
    } prev;

    prev.prevfile    = state.curfile;
    prev.prevlinenum = state.line_num;

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
    state.curfile  = prev.prevfile;
    state.line_num = prev.prevlinenum;
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
}