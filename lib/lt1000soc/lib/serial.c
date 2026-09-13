#include "lt1000.h"

char getc(void)
{
	while (!(UART_STATUS & UART_STATUS_RX_READY));
	return UART_DATA & 0xFF;
}

void putc(const char c)
{
	while (UART_STATUS & UART_STATUS_TX_FULL);
	UART_DATA = c;
}
	
void puts(const char *s)
{
	while (*s) {
		putc(*s++);
	}
}

void puts_hex(uint32_t v, int width)
{
	const char *hex = "0123456789ABCDEF";
	int x;
	
	for (x = 0; x < width * 2; x++) {
		putc(hex[(v>>28) & 0xF]);
		v <<= 4;
	}
}
