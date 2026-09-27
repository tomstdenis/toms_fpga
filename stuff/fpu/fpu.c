#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

uint32_t fadd(uint32_t a, uint32_t b)
{
	uint32_t a_sign, a_exp, a_mant;
	uint32_t b_sign, b_exp, b_mant;
	uint32_t issub;
	
	printf("a == %08lx\nb == %08lx\n", a, b);
	
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

int main(void)
{
	float a, b, *c;
	uint32_t *A, *B, r;
	
	A = (uint32_t *)&a;
	B = (uint32_t *)&b;
	c = (float *)&r;
	
	a = 1.337;
	b = 2.111;
	
	r = fadd(*A, *B);
	printf("%f + %f == %f\n", a, b, *c);
	r = fsub(*A, *B);
	printf("%f - %f == %f\n", a, b, *c);

	return 0;
}
