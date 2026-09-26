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
	txt_x   = (x == 0xFFFFFFFF) ? txt_x : x;
	txt_y   = (y == 0xFFFFFFFF) ? txt_y : y;
	txt_col = (col == 0xFFFFFFFF) ? txt_col : col;
}

// clear back buffer
void txt_clrscr(void)
{
	uint8_t *txt = (uint8_t*)VGA_ADDR;
	uint32_t x;
	for (x = 0; x < TXT_COLS * TXT_ROWS; x++) {
		*txt++ = 0;
		*txt++ = txt_col;
	}
	txt_cursor(0, 0, txt_col);
}

// scroll screen
void txt_scroll(void)
{
	uint8_t *txt = (uint8_t*)VGA_ADDR;
	uint32_t x;
	
	memcpy(txt, txt + TXT_COLS*2, TXT_COLS * (TXT_ROWS - 1) * 2);
	txt += TXT_COLS * (TXT_ROWS - 1) * 2;
	for (x = 0; x < TXT_COLS; x++) {
		*txt++ = 0x00;
		*txt++ = txt_col;
	}
}

// output char
void txt_putc(char c)
{
	// handle tab
	if (c == '\t') {
		// align to next column of 4
		do {
			txt_putc(' ');
		} while (txt_x & 3);
		return;
	}

	// backup for BS
	if ((c == 8 || c == 0x7f) && txt_x) {
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
		if (txt_y == TXT_ROWS) {
			txt_scroll();
			txt_y = TXT_ROWS - 1;
		}
		return;
	}

	uint8_t *txt = (uint8_t*)VGA_ADDR + (txt_y * 160 + txt_x * 2);
	txt[0] = ((c == 8 || c == 0x7f) ? ' ' : c);
	txt[1] = txt_col;
	
	if ((c != 8) && (c != 0x7F)) {
		++txt_x;
		if (txt_x == TXT_COLS) {
			++txt_y;
			txt_x = 0;
			if (txt_y == TXT_ROWS) {
				txt_scroll();
				txt_y = TXT_ROWS-1;
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

char *txt_gets(char *s)
{
	char *os = s, c;
	
	while (1) {
		c = getch();
		if (c == 8 || c == 0x7F) {
			if (s != os) {
				txt_putc(c);
				--s;
			}
		} else if (c == '\n' || c == '\r') {
			txt_putc(c == '\n' ? '\r' : '\n');
			txt_putc(c);
			break;
		} else {
			txt_putc(c);
			*s++ = c;
		}
	}
	*s = 0;
	return os;
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
