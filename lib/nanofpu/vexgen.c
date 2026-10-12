#define _GNU_SOURCE
#include <fenv.h>
#include <inttypes.h>
#include "almostmath.c"

int main(void)
{
    FILE *f;
    uint32_t f0x_in[8];
    uint32_t fxy_out[7];
    uint32_t fxy_opcode[7];
    uint32_t *pv, vector[22];
    uint32_t x, y, r;

/*
    x = 0x80000000;
    y = 0xc0f6216a;
    r = myfdiv(x, y);
    printf("0x%08lx\n", r);
    return 0;
*/

    f = fopen("fpu.hex", "w");

    for (x = 0; x < NUM_OF_TESTS; x++) {
        // fill inputs
        for (y = 0; y < 8; y++) {
            f0x_in[y] = rand_valid_float_bits();
        }
        // choose 7 opcodes
        for (y = 0; y < 7; y++) {
            fxy_opcode[y] = rand() % 4; // add,sub,mul,div
        }

        // do ops in first tier F0y
        for (y = 0; y < 4; y++) {
            switch (fxy_opcode[y]) {
                case 0: // add
                    r = myfadd(f0x_in[y*2+0], f0x_in[y*2+1]);
                    break;
                case 1: // sub
                    r = myfsub(f0x_in[y*2+0], f0x_in[y*2+1]);
                    break;
                case 2: // mul
                    r = myfmul(f0x_in[y*2+0], f0x_in[y*2+1]);
                    break;
                case 3: // div
                    r = myfdiv(f0x_in[y*2+0], f0x_in[y*2+1]);
                    break;
            }
            fxy_out[y] = r;
        }

        // do ops in 2nd and 3rd tiers F1y and F20
        for (y = 4; y < 7; y++) {
            switch (fxy_opcode[y]) {
                case 0: // add
                    r = myfadd(fxy_out[(y-4)*2 + 0], fxy_out[(y-4)*2 + 1]);
                    break;
                case 1: // sub
                    r = myfsub(fxy_out[(y-4)*2 + 0], fxy_out[(y-4)*2 + 1]);
                    break;
                case 2: // mul
                    r = myfmul(fxy_out[(y-4)*2 + 0], fxy_out[(y-4)*2 + 1]);
                    break;
                case 3: // div
                    r = myfdiv(fxy_out[(y-4)*2 + 0], fxy_out[(y-4)*2 + 1]);
                    break;
            }
            fxy_out[y] = r;
        }
 
        // make vector
        pv = &vector[0];
        *pv++ = fxy_opcode[6]; *pv++ = fxy_out[6]; // f20_opcode, f20_out
        *pv++ = fxy_opcode[5]; *pv++ = fxy_out[5]; // f11_opcode, f11_out
        *pv++ = fxy_opcode[4]; *pv++ = fxy_out[4]; // f10_opcode, f10_out
        *pv++ = fxy_opcode[3]; *pv++ = fxy_out[3]; *pv++ = f0x_in[3*2 + 1]; *pv++ = f0x_in[3*2 + 0]; // f03_opcode, f03_out, f03_in*2
        *pv++ = fxy_opcode[2]; *pv++ = fxy_out[2]; *pv++ = f0x_in[2*2 + 1]; *pv++ = f0x_in[2*2 + 0]; // f02_opcode, f02_out, f02_in*2
        *pv++ = fxy_opcode[1]; *pv++ = fxy_out[1]; *pv++ = f0x_in[1*2 + 1]; *pv++ = f0x_in[1*2 + 0]; // f01_opcode, f01_out, f01_in*2
        *pv++ = fxy_opcode[0]; *pv++ = fxy_out[0]; *pv++ = f0x_in[0*2 + 1]; *pv++ = f0x_in[0*2 + 0]; // f00_opcode, f00_out, f00_in*2
        for (y = 0; y < (7 + 7 + 8); y++) {
            fprintf(f, "%08"PRIx32, vector[y]);
        }
        fprintf(f, "\n");
    }
    fclose(f);
/*
{
    f20_opcode, f20_out, 
    f11_opcode, f11_out, 
    f10_opcode, f10_out, 
    f03_opcode, f03_out, f03_in,
    f02_opcode, f02_out, f02_in,
    f01_opcode, f01_out, f01_in,
    f00_opcode, f00_out, f00_in
} = cur_command;
*/
}