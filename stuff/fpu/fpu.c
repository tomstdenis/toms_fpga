#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

uint32_t fadd(uint32_t a, uint32_t b)
{
	uint32_t a_sign, a_exp, a_mant;
	uint32_t b_sign, b_exp, b_mant;
	uint32_t issub;
	
	// unpack 
	issub  = (a ^ b) >> 31; // XOR signs and extract

swapped:
	a_sign = a >> 31;
	a_exp  = (a >> 23) & 0xFF;
	a_mant = (a & ((1UL << 23) - 1)) | (1UL << 23);
	
	b_sign = b >> 31;
	b_exp  = (b >> 23) & 0xFF;
	b_mant = (b & ((1UL << 23) - 1)) | (1UL << 23);
	
	
	// sort 
	if (a_exp < b_exp || (a_exp == b_exp && a_mant < b_mant)) {
		uint32_t t;
		t = a; a = b; b = t;
		goto swapped;
	}
	
	// align
	while (b_exp < a_exp) {
		b_mant >>= 1;
		++b_exp;
	}
	
	// core operation
	if (issub) {
		a_mant -= b_mant;
	} else {
		a_mant += b_mant;
	}
	
	// normalize 
	while (a_mant >= (1UL << 24)) {
		a_mant >>= 1;
		a_exp   += 1;
	}
	while (a_mant && !(a_mant & (1UL << 23))) {
		a_mant <<= 1;
		a_exp   -= 1;
	}

	// repack
	return
		((a_sign & 1) << 31) |
		((a_exp & 0xFF) << 23) |
		(a_mant & ((1UL << 23) - 1));
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

int main(void)
{
	float a, b, *c;
	uint32_t *A, *B, r;
	
	A = (uint32_t *)&a;
	B = (uint32_t *)&b;
	c = (float *)&r;
	
	a = 1.2345;
	b = 2.3456;
	
	r = fadd(*A, *B);
	printf("%f + %f == %f (ref: %f)\n", a, b, *c, a + b);
	r = fsub(*A, *B);
	printf("%f - %f == %f (ref: %f)\n", a, b, *c, a - b);
	r = fmul(*A, *B);
	printf("%f * %f == %f (ref: %f)\n", a, b, *c, a * b);
	r = fdiv(*A, *B);
	printf("%f / %f == %f (ref: %f)\n", a, b, *c, a / b);

	return 0;
}
