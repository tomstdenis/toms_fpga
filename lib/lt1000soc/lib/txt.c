#include "lt1000.h"

// default to (0,0) dim white on black
static uint32_t txt_x = 0, txt_y = 0, txt_col = 0x70;

void txt_init(void)
{
	VGA_CTRL = 0;
	txt_x = txt_y = 0;
	txt_col = 0x70;
	txt_clrscr();
}

void txt_cursor(uint32_t x, uint32_t y, uint32_t col)
{
	txt_x = x; txt_y = y; txt_col = col;
}

// clear back buffer
void txt_clrscr(void)
{
	uint8_t *txt = (uint8_t*)VGA_ADDR;
	memset(txt, 0, 80 * 25 * 2);
	txt_cursor(0, 0, txt_col);
}

// scroll screen
void txt_scroll(void)
{
	uint8_t *txt = (uint8_t*)VGA_ADDR;
	memcpy(txt, txt + 160, 80 * 25 * 2 - 160);
	memset(txt + 80 * 24 * 2, 0, 160);
}

// output char
void txt_putc(char c)
{
	// backup for BS
	if (c == 8 && txt_x) {
		--txt_x;
	}
	
	// handle return
	if (c == '\r') {
		txt_x = 0;
		return;
	}
	
	// newline
	if (c == '\n') {
		++txt_y;
		if (txt_y == 25) {
			txt_scroll();
			txt_y = 24;
		}
		return;
	}

	uint8_t *txt = (uint8_t*)VGA_ADDR + (txt_y * 160 + txt_x * 2);
	txt[0] = (c == 8 ? ' ' : c);
	txt[1] = txt_col;
	
	if (c != 8) {
		++txt_x;
		if (txt_x == 80) {
			++txt_y;
			txt_x = 0;
			if (txt_y == 25) {
				txt_scroll();
				txt_y = 24;
			}
		}
	}
}

void txt_puts(char *s)
{
	while (*s) {
		txt_putc(*s++);
	}
}

void txt_vprintf(const char *fmt, va_list args)
{
	// 80x25 text mode buffer size is 2000 chars, so a 256-byte line 
	// stack buffer is plenty for formatted output lines.
	char buf[256];
	
	// vsnprintf handles all formatting, zero-padding, floats, %p, etc.
	vsnprintf(buf, sizeof(buf), fmt, args);
	
	txt_puts(buf);
}

void txt_printf(const char *fmt, ...)
{
	va_list args;
	va_start(args, fmt);
	txt_vprintf(fmt, args);
	va_end(args);
}
