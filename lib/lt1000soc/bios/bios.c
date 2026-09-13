#include <stdint.h>

#define UART_DATA     *((volatile uint32_t *)0x10000018)
#define UART_STATUS   *((volatile uint32_t *)0x1000001C)
#define UART_STATUS_TX_FULL  1
#define UART_STATUS_TX_EMPTY 2
#define UART_STATUS_RX_READY 4

// Simple blocking UART read
uint8_t uart_read_byte(void)
{
	uint8_t b;
    while (!(UART_STATUS & UART_STATUS_RX_READY)); // Poll until RX ready
    b = (uint8_t)(UART_DATA & 0xFF);
    UART_DATA = b;
    return b;
}

// Read a 32-bit little-endian integer over UART
uint32_t uart_read_u32(void) {
    uint32_t val = 0;
    val |= ((uint32_t)uart_read_byte());
    if (val == 27) {
		// normally this would suck but since binaries have to be a multiple of 4 bytes at a min 27 in the lower position is not valid
		return uart_read_u32();
	}
    val |= ((uint32_t)uart_read_byte()) << 8;
    val |= ((uint32_t)uart_read_byte()) << 16;
    val |= ((uint32_t)uart_read_byte()) << 24;
    return val;
}

void bios_main(void)
{
    uint8_t *psram_base = (uint8_t *)0x08000000;

    // 1. Receive 4-byte payload size from host
    uint32_t binary_size = uart_read_u32();

    // 2. Stream bytes into PSRAM (through nanocache)
    for (uint32_t i = 0; i < binary_size; i++) {
        psram_base[i] = uart_read_byte();
    }

    // 3. Cast PSRAM address to function pointer and execute!
    void (*app_entry)(void) = (void (*)(void))0x08000000;
    app_entry();
}
