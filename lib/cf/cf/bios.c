// CFLEA Primer25K BIOS

asm {
	ORG $F000
topofbios EQU *
	LD #$E000
	TAS				* Set stack to just below where we would load the boot sectors
	CALL main
?halt EQU *
	SJMP ?halt
}

#define SD_BIOS
#define SPI_ACCEL
#include "MCF/CFLEA.H"
#include "cf/lib/time.c"
#include "cf/lib/getc.c"
#include "cf/lib/gets.c"
#include "cf/lib/puts.c"
#include "cf/lib/hex.c"
#include "cf/lib/sd.c"

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
	puts("\n\rIniting SD...\n\r");
	if (!sd_reset()) {
		// read MBR to get LBA of partition 1
		sector[0] = sector[1] = 0;
		if (sd_sector_op(sector, 0xE000, 0) != 0) { goto terminal; }

		// LBA is 32-bit LE starting at offset 0x1C6 into the MBR
		fat16_lba[0] = sector[0] = *((unsigned *)0xE1C6);
		fat16_lba[1] = sector[1] = *((unsigned *)0xE1C8);

		// read first 8 sectors (4KB) from partition 1 (hard coded to sector 2048 onwards) at 0xE000 and jump there
		for (x = 0; x < 8; x++) {
			if (sd_sector_op(sector, 0xE000 + (0x200 * x), 0) != 0) { goto terminal; }
			// increment 32-bit sector
			sector[1] = sector[1] + ((sector[0] = sector[0] + 1) == 0 ? 1 : 0);
		}
		
		// check checksum
		for (x = y = 0; x < 0x1000; x++) {
			y = y + ((unsigned char *)0xE000)[x];
		}
		if (y & 0xFF) {
			puts("Invalid checksum\n\r");
			goto terminal;
		}
		
		// checksum ok, boot app
		puts("Jump to boot loader...\r\n");
		asm {
			JMP $E000
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
				puts("\n\rB: Boot\n\rM: Dump mem\n\rE: Edit mem\n\rS: Hex upload\n\rG: Go Addr\r\n");
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
				ch = read_hex(4);
				puts("\r\n");
				jump(ch);
				break;
		}	
		puts("\r\n");
	}
}

asm {
endofbios EQU *
}
