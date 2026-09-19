#include "lt1000.h"

int getch(void)
{
	while (!(UART_STATUS & UART_STATUS_RX_READY));
	return UART_DATA & 0xFF;
}

char *getstr(char *s)
{
	char *os = s, c;
	for(;;) { 
		c = getch();
		if (c == 10 || c == 13) {
			break;
		} else if (c == 8 && os != s) {
			--s;
		} else if (c > 13) {
			*s++ = c;
		}
	}
	*s = 0;
	return os;
}

void putch(const char c)
{
	while (UART_STATUS & UART_STATUS_TX_FULL);
	UART_DATA = c;
}
	
void putstr(const char *s)
{
	while (*s) {
		putch(*s++);
	}
}

void puts_hex(uint32_t v, int width)
{
	const char *hex = "0123456789ABCDEF";
	int x;
	
	for (x = 0; x < width * 2; x++) {
		putch(hex[(v>>28) & 0xF]);
		v <<= 4;
	}
}

void puts_dec(uint32_t v)
{
	const char *dec = "0123456789";
	char buf[16];
	int x, y;
	
	x = 0;
	while (v) {
		buf[x++] = dec[v%10];
		v /= 10;
	}
	if (!x) {
		putch('0');
	} else {
		while (x) {
			putch(buf[--x]);
		}
	}	
}
