#include "lt1000.h"

void main(void)
{
	uint32_t m = MCFG_DATA;
	getc();
	puts("MCFG.FREQ == "); puts_dec(MCFG_FREQ_MHZ(m)); puts("\r\n");
	puts("MCFG.TCM  == "); puts_dec(MCFG_TCM_BITS(m)); puts("\r\n");
	puts("MCFG.REV  == "); puts_hex(MCFG_SOC_REV(m), 1); puts("\r\n");

	void (*bios_entry)(void) = (void (*)(void))0x01000000;
	bios_entry();
}
