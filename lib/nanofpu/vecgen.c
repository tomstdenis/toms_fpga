#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>

uint32_t myfadd(uint32_t a, uint32_t b)
{
    // Handle subnormals/zeros simply (or strip sign/exp)
    uint32_t a_sign = a >> 31, a_exp = (a >> 23) & 0xFF;
    uint32_t b_sign = b >> 31, b_exp = (b >> 23) & 0xFF;

    // Handle 0 inputs quickly
    if ((a & 0x7FFFFFFF) == 0) return b;
    if ((b & 0x7FFFFFFF) == 0) return a;

    // Bit 27 is the hidden '1' bit (23 + 4)
    uint32_t a_mant = ((a & 0x7FFFFF) | (1UL << 23)) << 4;
    uint32_t b_mant = ((b & 0x7FFFFF) | (1UL << 23)) << 4;

    uint32_t issub = a_sign ^ b_sign;

    // Magnitude Sort: Ensure |A| >= |B|
    if (a_exp < b_exp || (a_exp == b_exp && a_mant < b_mant)) {
        uint32_t t_exp = a_exp;   a_exp = b_exp;   b_exp = t_exp;
        uint32_t t_mant = a_mant; a_mant = b_mant; b_mant = t_mant;
        a_sign = b_sign;
    }

    // Exponent Alignment with Sticky Bit
    uint32_t exp_diff = a_exp - b_exp;
    if (exp_diff >= 31) {
        b_mant = (b_mant != 0) ? 1 : 0;
    } else if (exp_diff > 0) {
        uint32_t sticky = 0; // (b_mant & ((1UL << exp_diff) - 1)) != 0;
        b_mant = (b_mant >> exp_diff) | sticky;
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

    // Renormalization in 28-bit space (Bit 27 is hidden bit)
    if (a_mant & (1UL << 28)) { 
        // Overflow (e.g. 1.x + 1.y = 10.z) -> Shift right, preserve sticky
        uint32_t sticky = a_mant & 1;
        a_mant = (a_mant >> 1) | sticky;
        a_exp += 1;
    } else {
        // Underflow -> Shift left until hidden bit is back at bit 27
        while (!(a_mant & (1UL << 27))) {
            a_mant <<= 1;
            a_exp -= 1;
        }
    }

    // Drop the 4 guard/extra bits (Truncate for Round-to-Zero)
    a_mant >>= 4;

    // Pack result
    return (a_sign << 31) | ((a_exp & 0xFF) << 23) | (a_mant & 0x7FFFFF);
}

uint32_t myfsub(uint32_t a, uint32_t b)
{
	return myfadd(a, b ^ 0x80000000);
}


uint32_t myfmul(uint32_t a, uint32_t b)
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
    while (prod & (1ULL << 47)) {
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

uint32_t myfdiv_serial(uint32_t sig_a, uint32_t sig_b)
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

uint32_t myfdiv(uint32_t a, uint32_t b)
{
    // 1. Unpack
    uint32_t a_sign = a >> 31;
    uint32_t a_exp  = (a >> 23) & 0xFF;
    uint32_t a_sig  = (a & 0x7FFFFF) | (1UL << 23);

    uint32_t b_sign = b >> 31;
    uint32_t b_exp  = (b >> 23) & 0xFF;
    uint32_t b_sig  = (b & 0x7FFFFF) | (1UL << 23);

    uint32_t res_sign = a_sign ^ b_sign;
    int32_t  res_exp  = (int32_t)a_exp - (int32_t)b_exp + 127;

    // 2. Serial Divide (25 bits returned)
    uint32_t res_mant = myfdiv_serial(a_sig, b_sig);
    
    // Normalize raw quotient
    if (!(res_mant & (1UL << 24))) {
        res_exp -= 1;
    } else {
        res_mant >>= 1; // Align so bit 23 is implicit 1.0
    }

    // 3. Subnormal Handling
    if (res_exp < 1) {
        int shift = 1 - res_exp;
        res_exp = 0;

        if (shift < 32) {
/*            uint32_t mask = (1UL << shift) - 1;
            uint32_t dropped = res_mant & mask;
            
            res_mant >>= shift;
*/
			while (shift) {
				res_mant = res_mant >> 1;
				shift    = shift - 1;
			}
        } else {
            res_mant = 0;
        }
    }

    // 4. Overflow Handling (Saturates to max float per test expectations)
    if (res_exp >= 255) {
        return (res_sign << 31) | 0x7F7FFFFF; // -FLT_MAX / +FLT_MAX
    }

    // 6. Pack
    return (res_sign << 31) | ((res_exp & 0xFF) << 23) | (res_mant & 0x7FFFFF);
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

// convert float to signed int
int32_t fsti(uint32_t x)
{
	uint32_t sign, exp, mant;
	
	// unpack
	sign = x >> 31;
	exp  = (x >> 23) & 0xFF;
	mant = (x & 0x7FFFFF)  | (1UL << 23);

	//range check
	if 	(exp < 127) {
		return 0;
	} else if (exp >= 158) {
		return sign ? 0x80000000 : 0x7FFFFFFF;
	}
	
	//norm
	exp = exp - 127;
	while (exp > 23) {
		mant = mant << 1;
		exp  = exp - 1;
	}
	
	while (exp < 23) {
		mant = mant >> 1;
		exp  = exp + 1;
	}
	
	return sign ? -mant : mant;
}

uint32_t myfsqrt(uint32_t x)
{
    // Unpack
    uint32_t sign = x >> 31;
    int      exp  = (x >> 23) & 0xFF;			  // exp is 8 bits
    uint64_t mant = ((x & 0x7FFFFFULL) | (1ULL << 23)) << 24; // mant/res are 49 bits...
    uint64_t res;
    
    if (sign) return 0xffc00000; // NaN
    if (exp == 0) return 0;
    
	// unbias and half the exponent (sub 1 and shift mantissa if exp is odd)
    if (exp & 1) {
		exp = (exp - 128) >> 1;
		mant = mant << 1;
	} else {
		exp = (exp - 127) >> 1;
	}
       
	// Digit-by-digit square root extraction (Restoring method)
    // 
    // Invariants per step testing bit k (from k=13 down to 0):
    //   - mant : Remaining remainder = X - (R_{k+1})^2
    //   - one  : Candidate bit weight squared = (2^k)^2 = 2^(2k)
    //   - res  : Pre-scaled cross-term        = 2 * R_{k+1} * 2^k
    //
    // Candidate expansion: (R_{k+1} + 2^k)^2 = (R_{k+1})^2 + [2 * R_{k+1} * 2^k + (2^k)^2]
    // The required extra delta to subtract is:  res + one
    
    uint64_t one = 1ULL << 48; // (2^24)^2 — starting mask for MSB (bit 13)
    res = 0;                  // Initial cross-term = 2 * R_14 * 2^13 = 0

    while (one != 0) {
        // Test if adding 2^k to the root keeps (candidate_root)^2 <= mantissa
        if (mant >= res + one) {
            // Bit k fits (1): deduct (2*R_{k+1}*2^k + 2^(2k)) from remainder
            mant -= res + one;

            // Prepare 'res' for step k-1 where R_k = R_{k+1} + 2^k:
            // Next res = 2 * R_k * 2^(k-1)
            //          = 2 * (R_{k+1} + 2^k) * 2^(k-1)
            //          = (2 * R_{k+1} * 2^k) / 2 + (2^k)^2
            //          = (res >> 1) + one
            res = (res >> 1) + one;
        } else {
            // Bit k does not fit (0): root remains R_k = R_{k+1}
            // Prepare 'res' for step k-1:
            // Next res = 2 * R_{k+1} * 2^(k-1) = res / 2
            res >>= 1;
        }

        // Scale mask down for step k-1: (2^(k-1))^2 = (2^2k) / 4
        one >>= 2;
    }

	// overflow
    if (res & (1UL << 24)) {
        res >>= 1;
        exp += 1;
    }
    
    // Normalize
    while (!(res & (1UL << 23))) {
        res <<= 1;
        exp -= 1;
    }
    
    // Re-bias exponent and pack
    exp = exp + 127;
    return ((exp & 0xFF) << 23) | (res & 0x7FFFFF);
}

uint32_t mycmp(uint32_t a, uint32_t b)
{
    uint32_t a_sign = a >> 31;
    uint32_t a_exp  = (a >> 23) & 0xFF;
    uint32_t a_sig  = a & 0x7FFFFF;

    uint32_t b_sign = b >> 31;
    uint32_t b_exp  = (b >> 23) & 0xFF;
    uint32_t b_sig  = b & 0x7FFFFF;

    // Special case for IEEE +0.0 == -0.0
    if ((a & 0x7FFFFFFF) == 0 && (b & 0x7FFFFFFF) == 0) {
        return 4; // EQ
    }

    // A is positive, B is negative -> A > B (GT = 2)
    if (!a_sign && b_sign) {
        return 2;
    }
    
    // A is negative, B is positive -> A < B (LT = 1)
    if (a_sign && !b_sign) {
        return 1;
    }

    // Both have the same sign
    if (a_exp < b_exp) {
        return a_sign ? 2 : 1; // If negative: GT (2), else: LT (1)
    } 
    if (a_exp > b_exp) {
        return a_sign ? 1 : 2; // If negative: LT (1), else: GT (2)
    }

    // Exponents are equal, compare mantissa/significand
    if (a_sig < b_sig) {
        return a_sign ? 2 : 1; // If negative: GT (2), else: LT (1)
    } 
    if (a_sig > b_sig) {
        return a_sign ? 1 : 2; // If negative: LT (1), else: GT (2)
    }

    return 4; // EQ
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

uint32_t iaddsub(uint32_t x, uint32_t y, uint32_t op)
{
    uint32_t a, b, c, d, A, B, C, D, j, k, J, K;

    a = x & 0x000000FF;
    b = (x & 0x0000FF00) >> 8;
    c = (x & 0x00FF0000) >> 16;
    d = (x & 0xFF000000) >> 24;

    A = y & 0x000000FF;
    B = (y & 0x0000FF00) >> 8;
    C = (y & 0x00FF0000) >> 16;
    D = (y & 0xFF000000) >> 24;

    j = x & 0x0000FFFF;
    k = x >> 16;

    J = y & 0x0000FFFF;
    K = y >> 16;

    switch (op) {
        case 0: // i8 add
            a = ((a + A) > 255) ? 255 : (a + A);
            b = ((b + B) > 255) ? 255 : (b + B);
            c = ((c + C) > 255) ? 255 : (c + C);
            d = ((d + D) > 255) ? 255 : (d + D);
            return a | (b << 8) | (c << 16) | (d << 24);
        case 1: // i8 sub
            a = (a < A) ? 0 : (a - A);
            b = (b < B) ? 0 : (b - B);
            c = (c < C) ? 0 : (c - C);
            d = (d < D) ? 0 : (d - D);
            return a | (b << 8) | (c << 16) | (d << 24);
        case 2: // i16 add
            j = ((j + J) > 65535) ? 65535 : (j + J);
            k = ((k + K) > 65535) ? 65535 : (k + K);
            return j | (k << 16);
        case 3: // i16 sub
            j = (j < J) ? 0 : (j - J);
            k = (k < K) ? 0 : (k - K);
            return j | (k << 16);
        case 4: // add32
            return x + y;
        case 5: // sub32
            return x - y;
        case 6: // cmp32
            if (x > y) return 2;
            if (x < y) return 1;
            return 4;
    }
    return 0xBEBEBEEF;
}

#define _GNU_SOURCE
#include <fenv.h>

void print_float(char *name, uint32_t f)
{
	float *ff = (float *)&f;
	printf("%s (0x%08x, %e): sign=%u, exp=%u(0x%x), mant=%u(0x%x)\n", name, f, *ff, f >> 31, (f >> 23) & 0xFF, (f >> 23) & 0xFF, f & 0x7FFFFF, f & 0x7FFFFF);
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

#if 0	
	*fa = 4.0; print_float("4.0", opa); *fa = *fa * *fa; print_float("**2", opa); opa = myfsqrt(opa); print_float("sqrt(**2)", opa);
	*fa = 10.0; print_float("10.0", opa); *fa = *fa * *fa; print_float("**2", opa); opa = myfsqrt(opa); print_float("sqrt(**2)", opa);
	*fa = 0.25; print_float("0.25", opa); *fa = *fa * *fa; print_float("**2", opa); opa = myfsqrt(opa); print_float("sqrt(**2)", opa);
	return 0;
#endif

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
	} else if (!strcmp(argv[1], "fsqrt")) {
		command = 6;
	} else if (!strcmp(argv[1], "fcmp")) {
		command = 7;
	} else if (!strcmp(argv[1], "i8add")) {
		command = 8;
	} else if (!strcmp(argv[1], "i8sub")) {
		command = 9;
	} else if (!strcmp(argv[1], "i16add")) {
		command = 10;
	} else if (!strcmp(argv[1], "i16sub")) {
		command = 11;
	} else if (!strcmp(argv[1], "add32")) {
		command = 12;
	} else if (!strcmp(argv[1], "sub32")) {
		command = 13;
	} else if (!strcmp(argv[1], "cmp32")) {
		command = 14;
	} else if (!strcmp(argv[1], "fpmul")) {
		command = 15;
	} else if (!strcmp(argv[1], "any")) {
		command = 16;
	}
	
	for (x = 0; x < NUM_OF_TESTS; x++) {
		if (command != 16) {
			op = command;
		} else {
			op = x % 13;
		}		
		
		opa = rand_valid_float_bits();
		opb = rand_valid_float_bits();
		switch (op) {
			case 1:
			case 0: //addsub
				opcode = rand() & 1;
				res    = opcode ? myfsub(opa, opb) : myfadd(opa, opb);
				fres   = opcode ? *fa - *fb : *fa + *fb;
				break;
			case 2: //mul
				opcode = 2;
				res    = myfmul(opa, opb);
				fres   = *fa * *fb;
				break;
			case 3: //div
				opcode = 3;
				res    = myfdiv(opa, opb);
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
				opcode = 5;
				opb    = 0;
				res    = fsti(opa);
				break;
			case 6: //fsqrt
				opcode = 6;
				opb    = 0;
				do {
					opa = rand_valid_float_bits();
					res    = myfsqrt(opa);
				} while (command == 7 && *fa <0.0);
				fres   = sqrtf(*fa);
				break;
			case 7: //cmp
				opcode = 7;
				res    = mycmp(opa, opb);
				break;
            case 8:
            case 9:
            case 10:
            case 11:
            case 12:
            case 13:
            case 14:
                opcode = op;
                res    = iaddsub(opa, opb, opcode - 8);
                break;
			case 15: //fpmul
				opcode = 15;
				res    = ((uint64_t)opa * opb) >> 16; 
				break;
		}
		
		if (opcode < 7 && opcode != 5 && *ufres != res) {
			printf("-------\nvector: opcode=%u output mismatch %x vs expt=%x\n", opcode, res, *ufres);
			printf("%e op %e == %e vs %e\n", *fa, *fb, *fures, fres);
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
