#include <math.h>
#include "lt1000.h"

TCM_FUNC(sfpmul16) uint32_t sfpmul16(uint32_t x, uint32_t y)
{
	return (((uint64_t)x * y) >> 16);
}

TCM_FUNC(iaddsub) uint32_t iaddsub(uint32_t x, uint32_t y, uint32_t op)
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
    }
}


TCM_FUNC(demo) void demo(void)
{
	volatile float a, b, r, r2;
	volatile uint32_t t, t1, t2, t3 = 4, r3, r4, r5;
	
	// calibrate timing
	t = TIMER;
	t = TIMER - t;

	getch();
	printf("Calibration: %u\n", t);
	
	// some sanity tests
	printf("x/0 == %f\n", a = fdiv(1.0f, 0.0f)); // test x/0 and also put NaN in a float
	printf("1.0 + NaN == %f\n", fadd(1.0f, a));
	printf("NaN + 1.0 == %f\n", fadd(a, 1.0f));
	printf("1.0 * NaN == %f\n", fmul(1.0f, a));
	printf("NaN * 1.0 == %f\n", fmul(a, 1.0f));
	printf("fsqrt(-1) == %f\n", fsqrt(-1.0f));
	printf("fsqrt(NaN) == %f\n", fsqrt(a));
	printf("fcmp(1.0, NaN) == %d\n", fcmp(1.0f, a));
	printf("fcmp(NaN, 1.0) == %d\n", fcmp(a, 1.0f));
	
	r4 = (65536 * 2 + 32768);
	r5 = (65536 * 2);
	t1 = TIMER;
	r3 = sfpmul16(r4, r5);
	t1 = TIMER - t1;
	printf("soft: 2.5 * 2 FP16.16 mult = %lu in %u cycles\n", r3, t1 - t);
	t1 = TIMER;
    fpmul16((65536 * 2 + 32768), (65536 * 2));
    r3 = fpmul16((65536 * 2 + 32768), (65536 * 2));
	t1 = TIMER - t1;
	printf("nano: 2.5 * 2 FP16.16 mult = %lu in %u cycles\n", r3, (t1 - t) >> 1);

	r4 = 0x7F017E02;
	r5 = 0x017F027E;
	t1 = TIMER;
	r3 = iaddsub(r4, r5, 0);
	t1 = TIMER - t1;
	printf("soft: iadd8(0x7F017E02, 0x017F027E) = 0x%08lx in %u cycles\n", r3, t1 - t);
	t1 = TIMER;
	iadd8(0x7F017E02, 0x017F027E);
	r3 = iadd8(0x7F017E02, 0x017F027E);
	t1 = TIMER - t1;
	printf("nano: iadd8(0x7F017E02, 0x017F027E) = 0x%08lx in %u cycles\n", r3, (t1 - t) >> 1);
	
	r4 = 0x7F017E02;
	r5 = 0x017F027E;
	t1 = TIMER;
	r3 = iaddsub(r4, r5, 1);
	t1 = TIMER - t1;
	printf("soft: isub8(0x7F017E02, 0x017F027E) = 0x%08lx in %u cycles\n", r3, t1 - t);
	t1 = TIMER;
	isub8(0x7F017E02, 0x017F027E);
	r3 = isub8(0x7F017E02, 0x017F027E);
	t1 = TIMER - t1;
	printf("nano: isub8(0x7F017E02, 0x017F027E) = 0x%08lx in %u cycles\n", r3, (t1 - t) >> 1);

	r4 = 0x7F017E02;
	r5 = 0x017F027E;
	t1 = TIMER;
	r3 = iaddsub(r4, r5, 2);
	t1 = TIMER - t1;
	printf("soft: iadd16(0x7F017E02, 0x017F027E) = 0x%08lx in %u cycles\n", r3, t1 - t);
	t1 = TIMER;
	iadd16(0x7F017E02, 0x017F027E);
	r3 = iadd16(0x7F017E02, 0x017F027E);
	t1 = TIMER - t1;
	printf("nano: iadd16(0x7F017E02, 0x017F027E) = 0x%08lx in %u cycles\n", r3, (t1 - t) >> 1);
	
	r4 = 0x7F017E02;
	r5 = 0x017F027E;
	t1 = TIMER;
	r3 = iaddsub(r4, r5, 3);
	t1 = TIMER - t1;
	printf("soft: isub16(0x7F017E02, 0x017F027E) = 0x%08lx in %u cycles\n", r3, t1 - t);
	t1 = TIMER;
	isub16(0x7F017E02, 0x017F027E);
	r3 = isub16(0x7F017E02, 0x017F027E);
	t1 = TIMER - t1;
	printf("nano: isub16(0x7F017E02, 0x017F027E) = 0x%08lx in %u cycles\n", r3, (t1 - t) >> 1);

	// float add
	a = 3.14f;
	b = 1.5f;
	t1 = TIMER;
	r = a + b;
	t1 = TIMER - t1;
	t2 = TIMER;
	fadd(3.14f, 1.5f);
	r2 = fadd(3.14f, 1.5f);
	t2 = TIMER - t2;
	printf("float: 3.14 + 1.5 == %f in %lu cycles\n", r, t1-t);
	printf("nano : 3.14 + 1.5 == %f in %lu cycles\n", r2, (t2-t)>>1);

	// float sub
	t1 = TIMER;
	r = a - b;
	t1 = TIMER - t1;
	t2 = TIMER;
	fsub(3.14f, 1.5f);
	r2 = fsub(3.14f, 1.5f);
	t2 = TIMER - t2;
	printf("float: 3.14 - 1.5 == %f in %lu cycles\n", r, t1-t);
	printf("nano : 3.14 - 1.5 == %f in %lu cycles\n", r2, (t2-t)>>1);

	// float mul
	t1 = TIMER;
	r = a * b;
	t1 = TIMER - t1;
	t2 = TIMER;
	fmul(3.14f, 1.5f);
	r2 = fmul(3.14f, 1.5f);
	t2 = TIMER - t2;
	printf("float: 3.14 * 1.5 == %f in %lu cycles\n", r, t1-t);
	printf("nano : 3.14 * 1.5 == %f in %lu cycles\n", r2, (t2-t)>>1);

	// float div
	t1 = TIMER;
	r = a / b;
	t1 = TIMER - t1;
	t2 = TIMER;
	fdiv(3.14f, 1.5f);
	r2 = fdiv(3.14f, 1.5f);
	t2 = TIMER - t2;
	printf("float: 3.14 / 1.5 == %f in %lu cycles\n", r, t1-t);
	printf("nano : 3.14 / 1.5 == %f in %lu cycles\n", r2, (t2-t)>>1);

	// float sqrt
	t1 = TIMER;
	r = sqrtf(a);
	t1 = TIMER - t1;
	t2 = TIMER;
	fsqrt(3.14f);
	r2 = fsqrt(3.14f);
	t2 = TIMER - t2;
	printf("float: sqrt(3.14) == %f in %lu cycles\n", r, t1-t);
	printf("nano : sqrt(3.14) == %f in %lu cycles\n", r2, (t2-t)>>1);

	// float sin
	a = 1.11f;
	t1 = TIMER;
	r = sinf(a);
	t1 = TIMER - t1;
	t2 = TIMER;
	r2 = fsin(1.11f);
	t2 = TIMER - t2;
	printf("float: sin(1.11) == %f in %lu cycles\n", r, t1-t);
	printf("nano : sin(1.11) == %f in %lu cycles\n", r2, t2-t);

	// float log2
	a = 6.28f;
	t1 = TIMER;
	r = log2f(a);
	t1 = TIMER - t1;
	t2 = TIMER;
	r2 = flog2(6.28f);
	t2 = TIMER - t2;
	printf("float: log2(6.28) == %f in %lu cycles\n", r, t1-t);
	printf("nano : log2(6.28) == %f in %lu cycles\n", r2, t2-t);

	// float log
	a = 1.11f;
	t1 = TIMER;
	r = logf(a);
	t1 = TIMER - t1;
	t2 = TIMER;
	r2 = flog(1.11f);
	t2 = TIMER - t2;
	printf("float: log(1.11) == %f in %lu cycles\n", r, t1-t);
	printf("nano : log(1.11) == %f in %lu cycles\n", r2, t2-t);

	// float pow
	a = 3.14;
	b = 1.5;
	t1 = TIMER;
	r = powf(a, b);
	t1 = TIMER - t1;
	t2 = TIMER;
	r2 = fpow(3.14, 1.5);
	t2 = TIMER - t2;
	printf("float: 3.14 ** 1.5 == %f in %lu cycles\n", r, t1-t);
	printf("nano : 3.14 ** 1.5 == %f in %lu cycles\n", r2, t2-t);

	// float fldi
	t1 = TIMER;
	r = t3;
	t1 = TIMER - t1;
	t2 = TIMER;
	r2 = fldi(t3);
	t2 = TIMER - t2;
	printf("float: fldi(4) == %f in %lu cycles\n", r, t1-t);
	printf("nano : fldi(4) == %f in %lu cycles\n", r2, t2-t);

	// float fsti
	t1 = TIMER;
	r3 = r;
	t1 = TIMER - t1;
	t2 = TIMER;
	r4 = fsti(r2);
	t2 = TIMER - t2;
	printf("float: fsti(4.0) == %d in %lu cycles\n", r3, t1-t);
	printf("nano : fsti(4.0) == %d in %lu cycles\n", r4, t2-t);


	delay_ms(5000);
}

int main(void)
{
	// reset FPU registers
	demo();
}
