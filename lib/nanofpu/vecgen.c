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
    
    // Check for explicit/implicit zero (or subnormal, flush-to-zero)
    if (a_exp == 0 || b_exp == 0) {
        return (a_sign ^ b_sign) << 31; // Flush subnormals/zeroes to signed zero
    }

    uint64_t a_sig = (a & 0x7FFFFF) | (1UL << 23);
    uint64_t b_sig = (b & 0x7FFFFF) | (1UL << 23);

    // 2. Compute Sign & Initial Exponent
    uint32_t res_sign = a_sign ^ b_sign;
    int32_t  res_exp  = (int32_t)a_exp + (int32_t)b_exp - 127;

    // 3. 24x24 Multiply -> 48-bit product
    uint64_t prod = a_sig * b_sig;

    // 4. Renormalize (Single-bit check)
    if (prod & (1ULL << 47)) {
        prod >>= 1;
        res_exp += 1;
    }

    // 5. Overflow / Underflow Handling (evaluated AFTER normalization)
    if (res_exp >= 255) {
        // Overflow -> Infinity (or max float 0x7F7FFFFF depending on rounding mode)
        return (res_sign << 31) | 0x7F7FFFFF;
    }
    if (res_exp <= 0) {
        // Underflow -> Flush to zero (preserving sign)
        return (res_sign << 31);
    }

    // 6. Pack (drop implicit bit 46)
    uint32_t res_mant = (prod >> 23) & 0x7FFFFF;

    return (res_sign << 31) | ((uint32_t)res_exp << 23) | res_mant;
}
uint32_t fdiv_serial(uint32_t sig_a, uint32_t sig_b)
{
    // sig_a and sig_b are 24-bit numbers [1.0, 2.0)
    uint64_t rem = (uint64_t)(sig_a & 0xFFFFFF) << 24; // Align dividend
    uint32_t div_reg = sig_b & 0xFFFFFF;
    uint32_t quot = 0;

    for (int count = 25; count > 0; count--) {
        quot <<= 1;
        uint32_t upper_rem = (uint32_t)(rem >> 24);

        if (upper_rem >= div_reg) {
            upper_rem -= div_reg;
            quot |= 1;
        }

        rem = ((uint64_t)upper_rem << 24) | (rem & 0xFFFFFF);
        rem <<= 1;
    }

    return quot; // Returns 25-bit quotient
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

    // 3. Serial Divide
    uint32_t quot = fdiv_serial(a_sig, b_sig);

    // 4. Renormalize Output
    uint32_t res_mant;
    if (quot & (1UL << 24)) {
        // Quotient in [1.0, 2.0): Bit 24 is implicit 1.
        // We drop bit 24 to keep 23 fractional bits [23:1] or [22:0].
        res_mant = (quot >> 1) & 0x7FFFFF; 
    } else {
        // Quotient in [0.5, 1.0): Bit 23 is implicit 1.
        res_mant = quot & 0x7FFFFF;
        res_exp -= 1;
    }

    // 5. Overflow / Underflow Handling (evaluated AFTER normalization)
    if (res_exp >= 255) {
        // Overflow -> Infinity (or max float 0x7F7FFFFF depending on rounding mode)
        return (res_sign << 31) | 0x7F7FFFFF;
    }
    if (res_exp <= 0) {
        // Underflow -> Flush to zero (preserving sign)
        return (res_sign << 31);
    }

    // 6. Pack
    return (res_sign << 31) | ((res_exp & 0xFF) << 23) | res_mant;
}

// convert signed int to float
uint32_t fldi(int32_t x)
{
	uint32_t r_sign, r_exp, r_mant;
	
	if (!x) return 0;
	
	// figure out sign
	if (x < 0) {
		r_sign = 1;
		r_mant = -x;
	} else {
		r_sign = 0;
		r_mant = x;
	}
	
	r_exp = 127 + 31; // max size
	
	// normalize
	while (!(r_mant & (1UL << 31))) {
		r_mant <<= 1;
		r_exp   -= 1;
	}
	
	return (r_sign << 31) | ((r_exp&0xFF)<<23) | ((r_mant >> 8) & 0x7FFFFF);
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

void print_float(char *name, uint32_t f)
{
	float *ff = (float *)&f;
	printf("%s (0x%08x, %f): sign=%u, exp=%u(0x%x), mant=%u(0x%x)\n", name, f, *ff, f >> 31, (f >> 23) & 0xFF, (f >> 23) & 0xFF, f & 0x7FFFFF, f & 0x7FFFFF);
}

int main(int argc, char **argv)
{
	FILE *vec;
	uint32_t opa, opb, res, opcode, x, *ufres;
	float *fa, *fb, fres, *fures;
	
	int command, op;
	
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
	
	if (!strcmp(argv[1], "addsub")) {
		command = 0;
	} else if (!strcmp(argv[1], "mul")) {
		command = 2;
	} else if (!strcmp(argv[1], "div")) {
		command = 3;
	} else if (!strcmp(argv[1], "fldi")) {
		command = 4;
	} else if (!strcmp(argv[1], "fsti")) {
		command = 5;
	} else if (!strcmp(argv[1], "any")) {
		command = 6;
	}
	
	for (x = 0; x < NUM_OF_TESTS; x++) {
		if (command != 6) {
			op = command;
		} else {
			op = rand() % 6;
		}		
		
		opa = rand_valid_float_bits();
		opb = rand_valid_float_bits();
		switch (op) {
			case 0: //addsub
				opcode = rand() & 1;
				res    = opcode ? fsub(opa, opb) : fadd(opa, opb);
				fres   = opcode ? *fa - *fb : *fa + *fb;
				break;
			case 2: //mul
				opcode = 2;
				res    = fmul(opa, opb);
				fres   = *fa * *fb;
				break;
			case 3: //div
				opcode = 3;
				res    = fdiv(opa, opb);
				fres   = *fa / *fb;
				break;
			case 4: //fldi
				opcode = 4;
				opb    = 0;
				opa    = (rand() << 15) ^ rand();
				res    = fldi(opa);
				fres   = (int32_t)opa;
				break;
			case 5: //fsti
				break;
		}
		
		if (*ufres != res) {
			printf("-------\nvector: opcode=%u output mismatch %x vs expt=%x\n", opcode, res, *ufres);
			printf("%f op %f == %f vs %f\n", *fa, *fb, *fures, fres);
			print_float("opa", opa);
			print_float("opb", opb);
			print_float("res", res);
			print_float("ufres", *ufres);
			printf("-------\n\n");
//			return -1;
		}
		
		fprintf(vec, "%02x%08x%08x%08x\n", opcode, res, opb, opa);
	}
	fclose(vec);
}
