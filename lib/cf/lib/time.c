// wait upto 255 ms
wait_ms(unsigned ms)
{
	asm {		
		OUT $11			* clear timer
wait_ms_top
		IN $11			* read timer
		CMP 2,S			* compare to ms 
		JZ wait_ms_top  * wait till ms passes
	}
}

wait_xms(unsigned ms)
{
	unsigned n;
	while (ms) {
		n = ms;
		if (ms > 255) {
			n = 255;
		}
		wait_ms(n);
		ms -= n;
	}
}
