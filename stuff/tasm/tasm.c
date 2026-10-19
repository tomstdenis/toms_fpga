#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdio.h>

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
        num_words;
    uint16_t
        word;    
} program[65536];

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

static void error(char *msg, char **p)
{
    fprintf(stderr, "ERROR: On line %u of file %s\n", state.file_name, state.line_num);
    fprintf(stderr, "ERROR: %s\n", msg);
    fprintf(stderr, "ERROR: Rest of line '%s'\n", *p);
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
            ret = 0b110
        } else if (matchcase(p, "Z")) {
            ret = 0b000;
        } else if (matchcase(p, "!Z")) {
            ret = 0b001;
        } else if (matchcase(p, "C")) {
            ret = 0b010;
        } else if (matchcase(p, "!C")) {
            ret = 0b011;
        } else {
            error("Unknown conditional code", p);
        }
        skip_whitespace(p);
        if (expect(p, ')')) {
            return ret;
        }
        error("Missing closing parenthesis for conditional code", p);
    }
    // default is always
    return 0b111;
}


int main(void)
{
}