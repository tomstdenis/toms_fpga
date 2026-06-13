// wait upto 65535 ms
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
