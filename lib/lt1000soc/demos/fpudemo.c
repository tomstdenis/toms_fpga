#include <math.h>
#include "lt1000.h"

TCM_FUNC(demo) void demo(void)
{
	volatile float a, b, r, r2;
	register uint32_t t, t1, t2;
	
	// calibrate timing
	t = TIMER;
	t = TIMER - t;

	getch();
	
	// Single fire float add
	t1 = TIMER;
	a = 3.14;
	b = 1.5;
	r = a + b;
	t1 = TIMER - t1;
	t2 = TIMER;
	FPU_IN_A = 3.14;
	FPU_IN_B = 1.5;
	FPU_CTRL = FPU_CTRL_OP_FADD | FPU_CTRL_VALID;
	while (!(FPU_CTRL & FPU_CTRL_VALID));
	r2 = FPU_OUT;
	t2 = TIMER - t2;
	printf("float: 3.14 + 1.5 == %f in %lu cycles\n", r, t1-t);
	printf("nano : 3.14 + 1.5 == %f in %lu cycles\n", r2, t2-t);
	
	// Single fire float multiply
	t1 = TIMER;
	a = 3.14;
	b = 1.5;
	r = a * b;
	t1 = TIMER - t1;
	t2 = TIMER;
	FPU_IN_A = 3.14;
	FPU_IN_B = 1.5;
	FPU_CTRL = FPU_CTRL_OP_FMUL | FPU_CTRL_VALID;
	while (!(FPU_CTRL & FPU_CTRL_VALID));
	r2 = FPU_OUT;
	t2 = TIMER - t2;
	printf("float: 3.14 * 1.5 == %f in %lu cycles\n", r, t1-t);
	printf("nano : 3.14 * 1.5 == %f in %lu cycles\n", r2, t2-t);

	// Auto fire float multiply, writes to FPU_IN_B trigger the last programmed job in FPU_CTRL
	FPU_CTRL = FPU_CTRL_AUTO_FIRE | FPU_CTRL_OP_FMUL;
	t2 = TIMER;
	FPU_IN_A = 3.14;
	FPU_IN_B = 1.5;
	while (!(FPU_CTRL & FPU_CTRL_VALID));
	r2 = FPU_OUT;
	t2 = TIMER - t2;
	printf("nano : 3.14 * 1.5 == %f in %lu cycles (AUTO FIRE ENABLED!!! PEW PEW)\n", r2, t2-t);
	FPU_CTRL = 0;
	
	// Single fire float divide
	t1 = TIMER;
	a = 3.14;
	b = 1.5;
	r = a / b;
	t1 = TIMER - t1;
	t2 = TIMER;
	FPU_IN_A = 3.14;
	FPU_IN_B = 1.5;
	FPU_CTRL = FPU_CTRL_OP_FDIV | FPU_CTRL_VALID;
	while (!(FPU_CTRL & FPU_CTRL_VALID));
	r2 = FPU_OUT;
	t2 = TIMER - t2;
	printf("float: 3.14 / 1.5 == %f in %lu cycles\n", r, t1-t);
	printf("nano : 3.14 / 1.5 == %f in %lu cycles\n", r2, t2-t);

	// Single fire float square root
	t1 = TIMER;
	a = 3.14;
	r = sqrtf(a);
	t1 = TIMER - t1;
	t2 = TIMER;
	FPU_IN_A = 3.14;
	FPU_CTRL = FPU_CTRL_OP_FSQRT | FPU_CTRL_VALID;
	while (!(FPU_CTRL & FPU_CTRL_VALID));
	r2 = FPU_OUT;
	t2 = TIMER - t2;
	printf("float: sqrt(3.14) == %f in %lu cycles\n", r, t1-t);
	printf("nano : sqrt(3.14) == %f in %lu cycles\n", r2, t2-t);

	delay_ms(5000);
}

int main(void)
{
	// reset FPU registers
	FPU_CTRL = 0;
	demo();
}
