#include "lt1000.h"

TCM_FUNC(demo) void demo(void)
{
	volatile float a, b, r, r2;
	uint32_t t, t1, t2;
	
	t = TIMER;
	t = TIMER - t;
	
	getch();
	
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

	FPU_CTRL = FPU_CTRL_AUTO_FIRE | FPU_CTRL_OP_FMUL;
	t2 = TIMER;
	FPU_IN_A = 3.14;
	FPU_IN_B = 1.5;
	while (!(FPU_CTRL & FPU_CTRL_VALID));
	r2 = FPU_OUT;
	t2 = TIMER - t2;
	printf("nano : 3.14 * 1.5 == %f in %lu cycles (AUTO FIRE ENABLED!!! PEW PEW)\n", r2, t2-t);

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


	delay_ms(5000);
}

int main(void)
{
	demo();
}
