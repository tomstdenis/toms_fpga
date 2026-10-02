#include <math.h>
#include "lt1000.h"

TCM_FUNC(demo) void demo(void)
{
	volatile float a, b, r, r2;
	volatile uint32_t t, t1, t2;
	
	// calibrate timing
	t = TIMER;
	t = TIMER - t;

	getch();
	
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
	printf("float: 3.14 + 1.5 == %f in %lu cycles\n", r, t1-t);
	printf("nano : 3.14 + 1.5 == %f in %lu cycles\n", r2, t2-t);

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


	delay_ms(5000);
}

int main(void)
{
	// reset FPU registers
	demo();
}
