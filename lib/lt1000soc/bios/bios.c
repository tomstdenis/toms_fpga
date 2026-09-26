#include "lt1000.h"

// Simple blocking UART read
static uint8_t uart_read_byte(int echo)
{
	uint8_t b;
    while (!(UART_STATUS & UART_STATUS_RX_READY)); // Poll until RX ready
    b = (uint8_t)(UART_DATA & 0xFF);
    if (echo) {
		UART_DATA = b;
	}
    return b;
}

// Read a 32-bit little-endian integer over UART, we expect 0x1B, 0x55, 0xAA before the length
static uint32_t uart_read_u32(void) {
    uint32_t val = 0;
top:
    val = ((uint32_t)uart_read_byte(1));
    if (val != 0x1B) goto top;
top55:
    val = ((uint32_t)uart_read_byte(1));
    if (val == 0x1B) goto top55;
    if (val != 0x55) goto top;
topAA:
    val = ((uint32_t)uart_read_byte(1));
    if (val == 0x1B) goto top55;
    if (val == 0x55) goto topAA;
    if (val != 0xAA) goto top;
    val  = (uint32_t)uart_read_byte(1);
    val |= ((uint32_t)uart_read_byte(1)) << 8;
    val |= ((uint32_t)uart_read_byte(1)) << 16;
    val |= ((uint32_t)uart_read_byte(1)) << 24;
    return val;
}

static void bios_putc(char c)
{
	txt_putc(c);
	while ((UART_STATUS & UART_STATUS_TX_FULL));
	UART_DATA = c;
}	

static void bios_puts(char *s) 
{
	while (*s) {
		bios_putc(*s++);
	}
}

static void init_sys(void)
{
	uint32_t *p;
	int32_t x, y;
	
	txt_init();
	
	bios_puts("\r\n\r\nBooting up BIOS ROM build: ");
	bios_puts(__DATE__);
	bios_puts(" ");
	bios_puts(__TIME__);
	bios_puts("\r\nInitializing device...\r\n");
	
	// reset GPIO
	GPIO_OE   = 0;
	GPIO_DATA = 0;
	
	// try and detect PSRAM size (write MiB counter at start of every 
	bios_puts("Sizing PSRAM (down to MiB)...\r\n");
	p = (uint32_t*)PSRAM_ADDR;
	for (x = 15; x >= 0; x--) {
		p[(x * 1024UL * 1024UL) >> 2] = x;
	}
	bios_puts("Total memory: ");
	for (x = 15; x >= 0; x--) {
		if (p[(x * 1024UL * 1024UL) >> 2] == x) {
			++x;
			bios_putc('0' + (x / 10));
			bios_putc('0' + (x % 10));
			// store PSRAM size
			MCFG_DATA = y = x;
			break;
		}
	}

	bios_puts(" MiB\r\n");

	bios_puts("Clearing PSRAM memory...\r\n");
	p = (uint32_t*)PSRAM_ADDR;
	for (x = 0; x < (y * 1024UL * 1024UL); x += 64) { 
		*p++ = 0; *p++ = 0; *p++ = 0; *p++ = 0; 
		*p++ = 0; *p++ = 0; *p++ = 0; *p++ = 0; 
		*p++ = 0; *p++ = 0; *p++ = 0; *p++ = 0; 
		*p++ = 0; *p++ = 0; *p++ = 0; *p++ = 0; 
	}
	bios_puts("Done.\r\n\r\n");
}	

void bios_main(void)
{
	struct fat32_disk *dsk;
	struct fat32_file *file;
	
	init_sys();
	
	dsk = fat32_init_disk(0, 4);
	if (!dsk) {
		bios_puts("Could not open VFAT from partition 1 of SD card\r\n");
	} else {
		bios_puts("SD card open...\n\r");
		file = fat32_open(dsk, "/BOOT.BIN");
		if (file) {
			bios_puts("Loading /BOOT.BIN...");
			fat32_read(file, (uint8_t*)PSRAM_ADDR, file->de->file_size);
			bios_puts("done.\r\n");
			goto exec;
		} else {
			bios_puts("/BOOT.BIN not found on disk.\r\n");
		}
	}
	
	bios_puts("Reverting to serial uploader (1Mbit/8N1)...\r\n");
		
    uint8_t *psram_base = (uint8_t *)PSRAM_ADDR;

    // 1. Receive 4-byte payload size from host
    uint32_t binary_size = uart_read_u32();

    // 2. Stream bytes into PSRAM (through nanocache)
    for (uint32_t i = 0; i < binary_size; i++) {
        psram_base[i] = uart_read_byte(0);
    }

exec:
    // 3. Cast PSRAM address to function pointer and execute!
    void (*app_entry)(void) = (void (*)(void))PSRAM_ADDR;
    app_entry();
}
