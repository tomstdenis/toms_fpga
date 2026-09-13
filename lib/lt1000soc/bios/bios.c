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

// Read a 32-bit little-endian integer over UART, we expect 0x1B, 0x55, 0xAA before the length
uint32_t uart_read_u32(void) {
    uint32_t val = 0;
top:
    val = ((uint32_t)uart_read_byte());
    if (val != 0x1B) goto top;
top55:
    val = ((uint32_t)uart_read_byte());
    if (val == 0x1B) goto top55;
    if (val != 0x55) goto top;
topAA:
    val = ((uint32_t)uart_read_byte());
    if (val == 0x1B) goto top55;
    if (val == 0x55) goto topAA;
    if (val != 0xAA) goto top;
    val  = (uint32_t)uart_read_byte();
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
