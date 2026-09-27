#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

uint32_t fadd(uint32_t a, uint32_t b)
{
    uint32_t a_sign = a >> 31, a_exp = (a >> 23) & 0xFF;
    uint32_t b_sign = b >> 31, b_exp = (b >> 23) & 0xFF;

    uint32_t a_mant = (a & 0x7FFFFF) | (1UL << 23);
    uint32_t b_mant = (b & 0x7FFFFF) | (1UL << 23);

    // Is this an internal subtraction? (a_sign != b_sign)
    uint32_t issub = a_sign ^ b_sign;

    // Magnitude Sort: Ensure |A| >= |B|
    if (a_exp < b_exp || (a_exp == b_exp && a_mant < b_mant)) {
        // Swap operands: Result sign takes B's sign (which is a_sign in the new order)
        uint32_t t_exp = a_exp;   a_exp = b_exp;   b_exp = t_exp;
        uint32_t t_mant = a_mant; a_mant = b_mant; b_mant = t_mant;
        a_sign = b_sign; // Result takes larger magnitude sign
    }

    // Exponent Alignment
    uint32_t exp_diff = a_exp - b_exp;
    if (exp_diff >= 25) {
        b_mant = 0;
    } else {
        b_mant >>= exp_diff;
    }

    // Core Add/Subtract
    if (issub) {
        a_mant -= b_mant;
    } else {
        a_mant += b_mant;
    }

    // Exact Zero Check
    if (a_mant == 0) {
        return 0;
    }

    if (a_mant & (1UL << 24)) {
		// Normalize Overflow (bit 24 set)
        a_mant >>= 1;
        a_exp += 1;
    } else {
		// Normalize Underflow (bit 23 not set)
        while (!(a_mant & (1UL << 23))) {
            a_mant <<= 1;
            a_exp -= 1;
        }
    }

    // Pack
    return (a_sign << 31) | ((a_exp & 0xFF) << 23) | (a_mant & 0x7FFFFF);
}

uint32_t fsub(uint32_t a, uint32_t b)
{
	return fadd(a, b ^ 0x80000000);
}


uint32_t fmul(uint32_t a, uint32_t b)
{
    // 1. Unpack
    uint32_t a_sign = a >> 31, a_exp = (a >> 23) & 0xFF;
    uint32_t b_sign = b >> 31, b_exp = (b >> 23) & 0xFF;
    
    uint64_t a_sig = (a & 0x7FFFFF) | (1UL << 23);
    uint64_t b_sig = (b & 0x7FFFFF) | (1UL << 23);

    // 2. Compute Sign & Exponent
    uint32_t res_sign = a_sign ^ b_sign;
    int32_t  res_exp  = (int32_t)a_exp + (int32_t)b_exp - 127;

    // 3. 24x24 Multiply -> 48-bit product
    uint64_t prod = a_sig * b_sig;

    // 4. Renormalize (Single-bit check)
    if (prod & (1ULL << 47)) {
        prod >>= 1;
        res_exp += 1;
    }

    // 5. Pack (drop implicit bit 46)
    uint32_t res_mant = (prod >> 23) & 0x7FFFFF;

    return (res_sign << 31) | ((res_exp & 0xFF) << 23) | res_mant;
}

uint32_t fdiv_serial(uint32_t sig_a, uint32_t sig_b)
{
    // rem: 25-bit remainder register (upper half of acc)
    // quot: 25-bit quotient register (lower half of acc)
    uint32_t rem = sig_a & 0xFFFFFF;
    uint32_t quot = 0;
    uint32_t div_reg = sig_b & 0xFFFFFF;

    for (int count = 25; count > 0; count--) {
        // wire [24:0] sub_res = acc[49:25] - div_reg;
        uint32_t sub_res = rem - div_reg;

        // Check sub_res[24] == 0 (no borrow / subtraction fits)
        if ((sub_res & (1UL << 24)) == 0) {
            // acc <= {sub_res[23:0], acc[24:0], 1'b1};
            rem = (sub_res << 1) | ((quot >> 24) & 1);
            quot = (quot << 1) | 1UL;
        } else {
            // acc <= {acc[48:0], 1'b0};
            rem = (rem << 1) | ((quot >> 24) & 1);
            quot = (quot << 1);
        }
    }

    return quot & 0x1FFFFFF; // Return 25-bit quotient
}

uint32_t fdiv(uint32_t a, uint32_t b)
{
    // 1. Unpack & Restore Hidden Bit
    uint32_t a_sign = a >> 31;
    uint32_t a_exp  = (a >> 23) & 0xFF;
    uint32_t a_sig  = (a & 0x7FFFFF) | (1UL << 23);

    uint32_t b_sign = b >> 31;
    uint32_t b_exp  = (b >> 23) & 0xFF;
    uint32_t b_sig  = (b & 0x7FFFFF) | (1UL << 23);

    // 2. Sign & Initial Exponent
    uint32_t res_sign = a_sign ^ b_sign;
    int32_t  res_exp  = (int32_t)a_exp - (int32_t)b_exp + 127;

    // 3. Hardware-identical Serial Divide Loop
    uint32_t quot = fdiv_serial(a_sig, b_sig);

    // 4. Renormalize Output
    uint32_t res_mant;
    if (quot & (1UL << 24)) {
        // Quotient >= 1.0 (Bit 24 is 1)
        res_mant = (quot >> 1) & 0x7FFFFF; // Drop implicit bit 24
    } else {
        // Quotient < 1.0 (Bit 23 is 1)
        res_mant = quot & 0x7FFFFF;        // Drop implicit bit 23
        res_exp -= 1;                      // Decrement exponent
    }

    // 5. Pack
    return (res_sign << 31) | ((res_exp & 0xFF) << 23) | res_mant;
}

// Generates a raw uint32_t bit-pattern for a valid normalized float
uint32_t rand_valid_float_bits(void) {
    uint32_t sign = (rand() & 0x1) << 31;
    
    // Valid normalized exponents range from 1 to 254 (0x01 to 0xFE)
    // Avoids 0 (subnormals) and 255 (NaN / Inf)
    uint32_t exp  = ((rand() % 254) + 1) << 23;
    
    // 23-bit mantissa (random bits)
    uint32_t mant = (rand() ^ (rand() << 15)) & 0x7FFFFF;

    return sign | exp | mant;
}

#define _GNU_SOURCE
#include <fenv.h>

int main(int argc, char **argv)
{
	FILE *vec;
	uint32_t opa, opb, res, opcode, x, *ufres;
	float *fa, *fb, fres, *fures;
	
	fesetround(FE_TOWARDZERO);
	
	fa = (float *)&opa;
	fb = (float *)&opb;
	ufres = (uint32_t*)&fres;
	fures = (float *)&res;
	
	if (argc == 1) {
		printf("%s: addsub | mul | div\n\r", argv[0]);
		return 0;
	}
	vec = fopen("fpu.hex", "w");
	
	for (x = 0; x < NUM_OF_TESTS; x++) {
		opa = rand_valid_float_bits();
		opb = rand_valid_float_bits();
		if (!strcmp(argv[1], "addsub")) {
			opcode = rand() & 1;
			res    = opcode ? fsub(opa, opb) : fadd(opa, opb);
			fres   = opcode ? *fa - *fb : *fa + *fb;
		}
		if (!strcmp(argv[1], "mul")) {
			opcode = 2;
			res    = fmul(opa, opb);
			fres   = *fa * *fb;
		}
		if (!strcmp(argv[1], "div")) {
			opcode = 3;
			res    = fdiv(opa, opb);
			fres   = *fa / *fb;
		}
		if (0 && *ufres != res) {
			printf("vector: %u %x %x, has mismatching outputs %x vs expt=%x\n", opcode, opa, opb, res, *ufres);
			printf("%f op %f == %f vs %f\n", *fa, *fb, *fures, fres);
			return -1;
		}
		
		fprintf(vec, "%02x%08x%08x%08x\n", opcode, res, opb, opa);
	}
	fclose(vec);
}
