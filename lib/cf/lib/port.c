#ifndef PORT_C_
#define PORT_C_

outport(int port, unsigned val)
{
	switch (port) {
		case 0:
			asm {
				LD 2,S
				OUT $01
			}
			break;
		case 1:
			asm {
				LD 2,S
				OUT $02
			}
			break;
		case 2:
			asm {
				LD 2,S
				OUT $03
			}
			break;
		case 3:
			asm {
				LD 2,S
				OUT $04
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
				OUT $05
			}
			break;
		case 1:
			asm {
				LD 2,S
				OUT $06
			}
			break;
		case 2:
			asm {
				LD 2,S
				OUT $07
			}
			break;
		case 3:
			asm {
				LD 2,S
				OUT $08
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
				IN $01
				RET
			}
			break;
		case 1:
			asm {
				LD 2,S
				IN $02
				RET
			}
			break;
		case 2:
			asm {
				LD 2,S
				IN $03
				RET
			}
			break;
		case 3:
			asm {
				LD 2,S
				IN $04
				RET
			}
			break;
	}
}

#endif
