// CFLEA Primer25K BIOS

asm {
	ORG $7000
topofbios EQU *
	LD  #$FF00				* set stack to the top of video memory - 256 to allow for temps
	TAS
	CALL main
?halt EQU *
	SJMP ?halt
}

#define SPI_FIXED
#define SD_BIOS
#define SD_NO_WRITE
#include <cflea.h>
#include "lib/time.c"
#include "lib/getc.c"
#include "lib/gets.c"
#include "lib/puts.c"
#include "lib/hex.c"
#include "lib/spi.c"
#include "lib/sd.c"

// MADDR.LEN
inspect_mem()
{
	unsigned addr, end, x;
	addr = read_hex(4);
	end = addr + 256;
	if (getc() == '.') {
		end = addr + read_hex(4);
	}
	for (x = 0; x < (end - addr); x++) {
		if (!(x & 15)) {
			puts("\r\n"); print_hex_word(addr + x); puts(": ");
		}
		print_hex_byte(((unsigned char*)addr)[x]);
		puts(" ");
	}
	puts("\r\n");
}

enter_mem()
{
}

// load hex format: S12310000000FFDED8F413D3FEEA11EB118402CCD5F9D9EB11EA11D90402E5A402E4D12D0C
serial_upload()
{
	unsigned code, ch, addr, len, olen;
	puts("\n\rWaiting for upload...\n\r");
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
				puts("Done uploading...\r\n");
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
	sd_init_fixed();
	puts("\n\rAttempting to read from SD card\n\r");
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
			puts("Invalid checksum, going to monitor\n\r");
			goto terminal;
		}
		
		// checksum ok, boot app
		asm {
			CLR
			IJMP
		}
	}
	puts("Failed to init SD card.\n\r");
terminal:
	// at this point we go interactive
	puts("Monitor:  Press H for help\n\r");
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
				x = read_hex(4);
				puts("\n\rJumping to 0x"); print_hex_word(x); puts("\n\r");
				jump(x);
				break;
			default:
				puts("? UNKNOWN\n\r");
		}	
	}
}

asm {
endofbios EQU *
}
