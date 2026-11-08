void flash_stream_to_sram(uint32_t flash_addr, uint32_t mem_addr, uint32_t len)
{
	uint8_t buf[32];
	while (len) {
		uint8_t blklen = len > 32 ? 32 : len;
		flash_read_block(flash_addr, buf, blklen);
		mem_write_block(mem_addr, blklen, buf);
		flash_addr += blklen;
		mem_addr += blklen;
		len -= blklen;
	}
}

#ifdef HOSTPC
#include <stdio.h>
#include <unistd.h>

void flash_init(void)
{
	FILE *f;

	// try to open the flash file
	f = fopen("emuflash.bin", "r+");
	if (!f) {
		// create new file and reset to 8MB
		f = fopen("emuflash.bin" , "w+");
		if (ftruncate(fileno(f), 1UL << 23)) {
			printf("Couldn't truncate flash file...\n");
		}
	}
	fclose(f);
}

void flash_erase_sector(uint32_t addr)
{
	FILE *f;
	uint8_t buf[4096];

	if (addr & 0xFFF) {
		return;
	}

	memset(buf, 0xFF, sizeof buf);
	f = fopen("emuflash.bin", "r+");
	fseek(f, addr, SEEK_SET);
	fwrite(buf, 1, 4096, f);
	fclose(f);
}

void flash_program_page(uint32_t addr, uint8_t *src)
{
	FILE *f;
	if (addr & 0xFF) {
		return;
	}
	f = fopen("emuflash.bin", "r+");
	fseek(f, addr, SEEK_SET);
	fwrite(src, 1, 256, f);
	fclose(f);
}

void flash_read_block(uint32_t addr, uint8_t *dst, uint16_t len)
{
	FILE *f;
	f = fopen("emuflash.bin", "r");
	fseek(f, addr, SEEK_SET);
	if (fread(dst, 1, len, f) != len) {
		printf("Error reading flash file..\n");
	}
	fclose(f);
}

#else

// this is in 01_mem.ino

#endif
