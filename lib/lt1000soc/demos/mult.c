#include "lt1000.h"

TCM_FUNC void demo(void)
{
	volatile uint32_t a, b, r;
	volatile uint64_t ab;
	
	uint32_t t0, t1, t2;
	
	// calibrate
	t0 = TIMER;
	t1 = TIMER;
	t2 = t1 - t0;

	// let's do 24.8 mult in SW
	t0 = TIMER;
	a = 0x11223344;
	b = 0x55667788;
	ab = (uint64_t)a * b;
	r = ab >> 8;
	t1 = TIMER;
	t1 = t1 - t0 - t2;
	puts("SW MULT took "); puts_dec(t1); puts("\r\nr = 0x"); puts_hex(r, 4);
	
	// let's do 24.8 mult in HW
	MULT_SCALER = 1;
	t0 = TIMER;
	MULT_IN_LO = 0x11223344;
	MULT_IN_HI = 0x55667788;
	r = MULT_OUT_LO;
	t1 = TIMER;
	t1 = t1 - t0 - t2;
	puts("\r\nHW MULT took "); puts_dec(t1); puts("\r\nr = 0x"); puts_hex(r, 4); puts("\r\n");
}

void main(void)
{
	getc();
	demo();
	demo();
	demo();
	void (*bios_entry)(void) = (void (*)(void))ROM_ADDR;
	bios_entry();
}
