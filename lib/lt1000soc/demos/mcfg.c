#include "lt1000.h"

void main(void)
{
	uint32_t m = MCFG_DATA;
	fprintf(stderr, "MCFG.FREQ  == %d MHz\n", MCFG_FREQ_MHZ(m));
	fprintf(stderr, "MCFG.TCM   == 2**%d KiB\n", MCFG_TCM_BITS(m));
	fprintf(stderr, "MCFG.REV   == %02x\n", MCFG_SOC_REV(m));
	fprintf(stderr, "MCFG.PSRAM == %d MiB\n", MCFG_PSRAM_MIB(m));
	getch();
}
