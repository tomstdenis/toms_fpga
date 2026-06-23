#ifndef PORT_C_
#define PORT_C_

#include "cf/lib/io.h"

outport(int port, unsigned val)
{
	switch (port) {
		case 0:
			asm {
				LD 2,S
				OUT PORT_PMOD_BASE+0
			}
			break;
		case 1:
			asm {
				LD 2,S
				OUT PORT_PMOD_BASE+1
			}
			break;
		case 2:
			asm {
				LD 2,S
				OUT PORT_PMOD_BASE+2
			}
			break;
		case 3:
			asm {
				LD 2,S
				OUT PORT_PMOD_BASE+3
			}
			break;
	}
}

dirport(int port, unsigned val)
{
	switch (port) {
		case 0:
			asm {
				LD 2,S
				OUT PORT_PMOD_DIR_BASE+0
			}
			break;
		case 1:
			asm {
				LD 2,S
				OUT PORT_PMOD_DIR_BASE+1
			}
			break;
		case 2:
			asm {
				LD 2,S
				OUT PORT_PMOD_DIR_BASE+2
			}
			break;
		case 3:
			asm {
				LD 2,S
				OUT PORT_PMOD_DIR_BASE+3
			}
			break;
	}
}

inport(int port, unsigned tgl)
{
	switch (port) {
		case 0:
			asm {
				LD 2,S
				IN PORT_PMOD_BASE+0
				RET
			}
			break;
		case 1:
			asm {
				LD 2,S
				IN PORT_PMOD_BASE+1
				RET
			}
			break;
		case 2:
			asm {
				LD 2,S
				IN PORT_PMOD_BASE+2
				RET
			}
			break;
		case 3:
			asm {
				LD 2,S
				IN PORT_PMOD_BASE+3
				RET
			}
			break;
	}
}

#endif
