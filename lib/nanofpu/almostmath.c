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

    // Bit 27 is the hidden '1' bit (23 + 4)
    uint32_t a_mant = ((a & 0x7FFFFF) | (1UL << 23)) << 4;
    uint32_t b_mant = ((b & 0x7FFFFF) | (1UL << 23)) << 4;

    // NaN prop
    if ((a_exp == 0xFF && (a & ((1UL << 23) - 1))) || (b_exp == 0xFF && (b & ((1UL << 23) - 1)))) {
        return 0x7fc00000 | ((a ^ b) & 0x80000000);
    }

    // Handle 0 inputs quickly
    if ((a & 0x7FFFFFFF) == 0 && (b & 0x7FFFFFFF) == 0) return (a ^ b) & 0x80000000;
    if ((a & 0x7FFFFFFF) == 0) return b;
    if ((b & 0x7FFFFFFF) == 0) return a;

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
        b_mant = ((b_mant & 0x7FFFFF0) != 0) ? 1 : 0;
    } else {
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
    if (0 && a_mant == 0) {
        return 0;
    }

    // Renormalization in 28-bit space (Bit 27 is hidden bit)
    if (a_mant & (1UL << 28)) { 
        // Overflow (e.g. 1.x + 1.y = 10.z) -> Shift right
        a_mant = (a_mant >> 1);
        a_exp += 1;
    } else {
        // Underflow -> Shift left until hidden bit is back at bit 27
        while (a_mant && !(a_mant & (1UL << 27))) {
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
    uint64_t a_sig = (a & 0x7FFFFF) | (1UL << 23);
    uint64_t b_sig = (b & 0x7FFFFF) | (1UL << 23);
  
    // NaN prop
    if ((a_exp == 0xFF && (a & ((1UL << 23) - 1))) || (b_exp == 0xFF && (b & ((1UL << 23) - 1)))) {
        return 0x7fc00000 | ((a ^ b) & 0x80000000);
    }

    // Check for explicit/implicit zero (or subnormal, flush-to-zero)
    if ((a & 0x7FFFFFFF) == 0 || (b & 0x7FFFFFFF) == 0) {
        return (a_sign ^ b_sign) << 31; // Flush subnormals/zeroes to signed zero
    }

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

    // NaN prop
    if ((a_exp == 0xFF && (a & ((1UL << 23) - 1))) || (b_exp == 0xFF && (b & ((1UL << 23) - 1)))) {
        return 0x7fc00000 | ((a ^ b) & 0x80000000);
    }

    // divide by zero...
    if ((b & 0x7FFFFFFF) == 0) {
        return 0x7fc00000 | ((a ^ b) & 0x80000000);
    }

    // divide zero by ...
    if ((a & 0x7FFFFFFF) == 0) {
        return (a ^ b) & 0x80000000;
    }

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
