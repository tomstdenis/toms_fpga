#include <math.h>
#include "lt1000.h"

TCM_FUNC(sfpmul16) uint32_t sfpmul16(uint32_t x, uint32_t y)
{
	return (((uint64_t)x * y) >> 16);
}

TCM_FUNC(demo) void demo(void)
{
	volatile float a, b, r, r2;
	volatile uint32_t t, t1, t2, t3 = 4, r3, r4;
	
	// calibrate timing
	t = TIMER;
	t = TIMER - t;

	getch();
	printf("Calibration: %u\n", t);
	
	t1 = TIMER;
	r3 = sfpmul16((65536 * 2 + 32768), (65536 * 2));
	t1 = TIMER - t1;
	printf("16.16 SW FP mult = %lu in %u cycles\n", r3, t1 - t);
	t1 = TIMER;
	r3 = fpmul16((65536 * 2 + 32768), (65536 * 2));
	t1 = TIMER - t1;
	printf("16.16 HW FP mult = %lu in %u cycles\n", r3, t1 - t);
	
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
	
	// float add
	t1 = TIMER;
	a = 3.14;
	b = 1.5;
	r = a + b;
	t1 = TIMER - t1;
	t2 = TIMER;
	r2 = fadd(3.14, 1.5);
	t2 = TIMER - t2;
	printf("float: 3.14 + 1.5 == %f in %lu cycles\n", r, t1-t);
	printf("nano : 3.14 + 1.5 == %f in %lu cycles\n", r2, t2-t);

	// float sub
	t1 = TIMER;
	a = 3.14;
	b = 1.5;
	r = a - b;
	t1 = TIMER - t1;
	t2 = TIMER;
	r2 = fsub(3.14, 1.5);
	t2 = TIMER - t2;
	printf("float: 3.14 - 1.5 == %f in %lu cycles\n", r, t1-t);
	printf("nano : 3.14 - 1.5 == %f in %lu cycles\n", r2, t2-t);

	// float mul
	t1 = TIMER;
	a = 3.14;
	b = 1.5;
	r = a * b;
	t1 = TIMER - t1;
	t2 = TIMER;
	r2 = fmul(3.14, 1.5);
	t2 = TIMER - t2;
	printf("float: 3.14 * 1.5 == %f in %lu cycles\n", r, t1-t);
	printf("nano : 3.14 * 1.5 == %f in %lu cycles\n", r2, t2-t);

	// float div
	t1 = TIMER;
	a = 3.14;
	b = 1.5;
	r = a / b;
	t1 = TIMER - t1;
	t2 = TIMER;
	r2 = fdiv(3.14, 1.5);
	t2 = TIMER - t2;
	printf("float: 3.14 / 1.5 == %f in %lu cycles\n", r, t1-t);
	printf("nano : 3.14 / 1.5 == %f in %lu cycles\n", r2, t2-t);

	// float sqrt
	t1 = TIMER;
	a = 3.14;
	r = sqrtf(a);
	t1 = TIMER - t1;
	t2 = TIMER;
	r2 = fsqrt(3.14);
	t2 = TIMER - t2;
	printf("float: sqrt(3.14) == %f in %lu cycles\n", r, t1-t);
	printf("nano : sqrt(3.14) == %f in %lu cycles\n", r2, t2-t);

	// float sin
	t1 = TIMER;
	a = 1.11;
	r = sinf(a);
	t1 = TIMER - t1;
	t2 = TIMER;
	r2 = fsin(1.11);
	t2 = TIMER - t2;
	printf("float: sin(1.11) == %f in %lu cycles\n", r, t1-t);
	printf("nano : sin(1.11) == %f in %lu cycles\n", r2, t2-t);

	// float log2
	t1 = TIMER;
	a = 6.28;
	r = log2f(a);
	t1 = TIMER - t1;
	t2 = TIMER;
	r2 = flog2(6.28f);
	t2 = TIMER - t2;
	printf("float: log2(6.28) == %f in %lu cycles\n", r, t1-t);
	printf("nano : log2(6.28) == %f in %lu cycles\n", r2, t2-t);

	// float log
	t1 = TIMER;
	a = 1.11;
	r = logf(a);
	t1 = TIMER - t1;
	t2 = TIMER;
	r2 = flog(1.11);
	t2 = TIMER - t2;
	printf("float: log(1.11) == %f in %lu cycles\n", r, t1-t);
	printf("nano : log(1.11) == %f in %lu cycles\n", r2, t2-t);

	// float pow
	t1 = TIMER;
	a = 3.14;
	b = 1.5;
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
