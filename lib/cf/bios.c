// CFLEA Primer25K BIOS

asm {
	ORG $F000
topofbios EQU *
	LD  #$FF00				* set stack to the top of video memory - 256 to allow for temps
	TAS
	CALL main
?halt EQU *
	SJMP ?halt
}

#define SPI_FIXED
#define SD_BIOS
#include <cflea.h>
#include "lib/time.c"
#include "lib/getc.c"
#include "lib/gets.c"
#include "lib/puts.c"
#include "lib/spi.c"
#include "lib/sd.c"

main() {
}

asm {
endofbios EQU *
}
