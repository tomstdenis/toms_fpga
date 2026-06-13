// wait upto 65535 us
wait_us(unsigned us)
{
	asm {		
		OUT $11			 * clear timer
wait_us_top
		IN $11			 * read timer
		CMP 2,S			 * compare to us
		ULT				 * unsigned less than 
		SJNZ wait_us_top * wait till us passes
	}
}

wait_ms(unsigned ms)
{
	while (ms--) {
		wait_us(1000);
	}
}

unsigned delay_loops(unsigned x)
{
	asm {
		OUT $11					* clear 1us timer
		LD 2,S					* load x
delay_loops_top EQU *
		DEC
		SJNZ delay_loops_top	* decrement and loop
		IN $11					* read 1us timer and return value
	}
}

// return the # of delay_loops per ms
unsigned delay_calibrate()
{
	unsigned x, t, top, bot;
	
	bot = 0; top = 0xFFFF;
	do {
		x = (top + bot) >> 1;
		t = delay_loops(x);
		if (t > 1000) {
			top = x;
		} else {
			bot = x;
		}
	} while (top != bot);
	return x;
}
