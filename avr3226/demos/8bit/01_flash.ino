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

#include <SPI.h>

// code to drive a MX25L6433F on PA6
#define CS_PORT VPORTC
#define CS_PIN_BM PIN0_bm

void flash_init(void)
{
	// set CS pin high as it's active low
	CS_PORT.DIR |= CS_PIN_BM;
	CS_PORT.OUT |= CS_PIN_BM;
}

static void flash_wait_wip(void)
{
	uint8_t res;

    // Start Transaction FIRST (configures pins & interrupts)
    SPI.beginTransaction(SPISettings(10000000, MSBFIRST, SPI_MODE0));

    // Set CS active
    CS_PORT.IN = CS_PIN_BM;

    // Send command
    SPI.transfer(0x05);       			// Command: Read status register
    do {
		res = SPI.transfer(0x00);
	} while (res & 0x01);				// Wait for WIP bit to go to zero
	
    // Set CS idle
    CS_PORT.IN = CS_PIN_BM;

    // End Transaction LAST
    SPI.endTransaction();
}


static void flash_set_wren(void)
{
	// Start Transaction FIRST (configures pins & interrupts)
	SPI.beginTransaction(SPISettings(10000000, MSBFIRST, SPI_MODE0));

	// Set CS active
	CS_PORT.IN = CS_PIN_BM;

	// Send command
	SPI.transfer(0x06);       			// Command: Set WREN

	// Set CS idle
	CS_PORT.IN = PIN6_bm;

	// End Transaction LAST
	SPI.endTransaction();
}

// address of sector to erase addr[11:0] should be zero
void flash_erase_sector(uint32_t addr)
{
	// sanity check sector is 4KB aligned
	if (addr & 0xFFF) {
		return;
	}

	// wait for WIP
	flash_wait_wip();
	    
	// set WREN
	flash_set_wren();

    // Start Transaction FIRST (configures pins & interrupts)
    SPI.beginTransaction(SPISettings(10000000, MSBFIRST, SPI_MODE0));

    // Set CS active
    CS_PORT.IN = CS_PIN_BM;

    // Send command and 24-bit address
    SPI.transfer(0x20);       			// Command: erase sector
    SPI.transfer(addr >> 16);       	// Address [23:16]
    SPI.transfer((addr >> 8) & 0xFF);   // Address [15:8]
    SPI.transfer(addr & 0xFF);			// Address [7:0]

    // Set CS idle
    CS_PORT.IN = CS_PIN_BM;

    // End Transaction LAST
    SPI.endTransaction();

	// wait for WIP so we're in a known state when we return
	flash_wait_wip();
}

// program 256 bytes, addr[7:0] should be zero
void flash_program_page(uint32_t addr, uint8_t *src)
{
	uint16_t x;
	
	// sanity check address must be page aligned
	if (addr & 0xFF) {
		return;
	}

	// wait for WIP
	flash_wait_wip();
	    
	// set WREN
	flash_set_wren();

    // Start Transaction FIRST (configures pins & interrupts)
    SPI.beginTransaction(SPISettings(10000000, MSBFIRST, SPI_MODE0));

    // Set CS active
    CS_PORT.IN = CS_PIN_BM;

    // Send command and 24-bit address
    SPI.transfer(0x02);       			// Command: page program
    SPI.transfer(addr >> 16);       	// Address [23:16]
    SPI.transfer((addr >> 8) & 0xFF);   // Address [15:8]
    SPI.transfer(addr & 0xFF);			// Address [7:0]
    for (x = 0; x < 256; x++) {
		SPI.transfer(*src++);
	}

    // Set CS idle
    CS_PORT.IN = CS_PIN_BM;

    // End Transaction LAST
    SPI.endTransaction();

	// wait for WIP so we're in a known state when we return
	flash_wait_wip();	
}

void flash_read_block(uint32_t addr, uint8_t *dst, uint16_t len)
{	
	// wait for WIP (in case something else started a write)
	flash_wait_wip();
	    
    // Start Transaction FIRST (configures pins & interrupts)
    SPI.beginTransaction(SPISettings(10000000, MSBFIRST, SPI_MODE0));

    // Set CS active
    CS_PORT.IN = CS_PIN_BM;

    // Send command and 24-bit address
    SPI.transfer(0x03);       			// Command: read bytes
    SPI.transfer(addr >> 16);       	// Address [23:16]
    SPI.transfer((addr >> 8) & 0xFF);   // Address [15:8]
    SPI.transfer(addr & 0xFF);			// Address [7:0]
    SPI.transfer(dst, len);

    // Set CS idle
    CS_PORT.IN = CS_PIN_BM;

    // End Transaction LAST
    SPI.endTransaction();
}

#undef CS_PORT
#undef CS_PIN_BM

#endif
