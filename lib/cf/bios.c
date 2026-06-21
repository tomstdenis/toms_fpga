// CFLEA Primer25K BIOS

asm {
	ORG $F000
topofbios EQU *
	CLR
	TAS				* Set stack to top of memory
	CALL main
?halt EQU *
	SJMP ?halt
}

#define SD_BIOS
#define SD_NO_WRITE
#include <cflea.h>
#include "lib/time.c"
#include "lib/getc.c"
#include "lib/gets.c"
#include "lib/puts.c"
#include "lib/hex.c"
#include "lib/sd.c"

// MADDR.LEN
inspect_mem()
{
	unsigned addr, end, x;
	addr = read_hex(4) & 0xFFF0;
	end = addr + 256;
	if (getc() == '.') {
		end = addr + read_hex(4);
	}
	for (x = end - addr; x--;) {
		if (!(addr & 15)) {
			puts("\r\n"); print_hex_word(addr); puts(": ");
		}
		print_hex_byte(*((unsigned char*)addr++));
		puts(" ");
	}
	puts("\r\n");
}

enter_mem()
{
	unsigned addr, ch;
	addr = read_hex(4);
	while (getc() == ' ') {
		ch = read_hex(2);
		*((unsigned char*)addr++) = ch;
	}
}

// load hex format: S12310000000FFDED8F413D3FEEA11EB118402CCD5F9D9EB11EA11D90402E5A402E4D12D0C
serial_upload()
{
	unsigned code, ch, addr, len, olen;
	getc_echo = 0x00;
	for (;;) {
		ch = getc();
		if (ch == 'S') {
			// read digit
			code = getc();
			// read # of bytes
			olen = len = read_hex(2) - 3;
			// read addr
			addr = read_hex(4);
			while(len--) {
				ch = read_hex(2);
				*((unsigned char*)addr++) = ch;
			}
			getc();
			getc(); // checksum
			if (code == '9' && !olen) {
				wait_ms(100);
				do {
					ch = getch();
				} while (ch == '\r' || ch == '\n');
				return;
			}
		}
	}
}

jump(unsigned x) {
	asm {
		LD 2,S
		IJMP
	}
}

main() {
	unsigned sector[2], x, y;
	unsigned ch;
boot_sd:
	sd_init();
	puts("\n\rReading SD card\n\r");
	if (!sd_reset()) {
		// read first 8 sectors (4KB) at 0x0000 and jump there
		sector[1] = 0;
		for (sector[0] = 0; sector[0] < 8; sector[0]++) {
			if (sd_sector_op(sector, 0x0000, 0) != 0) { goto terminal; }
		}
		
		// check checksum
		for (x = y = 0; x < 0x1000; x += 2) {
			y = y + *((unsigned*)x) + 1;
		}
		if (y) {
			puts("Invalid checksum\n\r");
			goto terminal;
		}
		
		// checksum ok, boot app
		asm {
			CLR
			IJMP
		}
	}
	puts("Failed to init SD card.");
terminal:
	// at this point we go interactive
	puts("\n\rMonitor:  Press H for help\n\r");
	for (;;) {
		getc_echo = 0xFF;
		puts("* ");
		ch = getc();
		switch (ch) {
			case 'H':
				puts("\n\rB: Boot SD\n\rM: Inspect memory\n\rE: Enter memory\n\rS: Serial upload\n\rG: Go Addr\r\n");
				break;
			case 'B':
				goto boot_sd;
			case 'M':
				inspect_mem();
				break;
			case 'E':
				enter_mem();
				break;
			case 'S':
				serial_upload();
				break;
			case 'G':
				jump(read_hex(4));
				break;
			default:
				puts("?\n\r");
		}	
	}
}

asm {
endofbios EQU *
}
