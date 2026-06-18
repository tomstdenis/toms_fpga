#ifndef CONSOLE_C_
#define CONSOLE_C_

#define vidmem ((unsigned char *)0xF800)

// store console variables at end of vidmem
// this leaves the main 60K block totally free for
// the app
// use 0xFFF0..0xFFFF for console code
#define console_x ((unsigned *)(0xFFFE))
#define console_y ((unsigned *)(0xFFFC))
#define console_tx ((unsigned *)(0xFFFA))
#define console_ty ((unsigned *)(0xFFF8))

// clear screen and reset x/y to 0
c_clrscr(void) {
	memset(vidmem, 0, 2048);
}

c_scroll(void) {
	memcpy(vidmem, vidmem + 80, 24 * 80);
	memset(vidmem + 80 * 24, ' ', 80);
}

// rewind the cursor 
c_rewind() {
	if (*console_x == 0) {
		if (*console_y != 0) {
			--(*console_y);
			*console_x = 79;
		}
	} else {
		--(*console_x);
	}
}

c_gotoxy(unsigned x, unsigned y) {
	*(console_x) = x;
	*(console_y) = y;
}

c_putc(char c) {
	if (c == '\n') {
		*(console_x) = 0;
		goto newline;
	}
	vidmem[*console_y * 80 + *console_x] = c;
	++(*console_x);
	if (*console_x == 80) {
		*console_x = 0;
newline:
		++(*console_y);
		if (*console_y == 25) {
			c_scroll();
			*console_y = 24;
		}
	}
}

c_puts(char *s) {
	while (*s) {
		c_putc(*s++);
	}
}

unsigned c_serin(void) {
	asm {
		IN $00
	}
}

unsigned c_getc(void) {
	unsigned ch;
	do {
		ch = c_serin();
	} while (ch == 0xFFFF);
	return ch;
}

c_gets(char *s, int n)
{
	char *os, *on;
	unsigned ch;
	os = s;
	on = s + n - 1;
	for (;;) {
		ch = c_getc();
		if (ch == 8) {
			// backspace
			if (s != os) {
				--s;
				c_rewind();
				c_putc(' ');
				c_rewind();
			}
		} else {
			if (ch == '\n' || ch == '\r') {
				*s = 0;
				return;
			} else {
				if (s != on) {
					*s++ = ch;
					c_putc(ch);
				}
			}
		}
	}
}

c_box(unsigned x1, unsigned y1, unsigned x2, unsigned y2) {
	unsigned x, y;
	
	*console_tx = *console_x;
	*console_ty = *console_y;
	
	for (x = x1; x < x2; x++) {
		for (y = y1; y < y2; y++) {
			c_gotoxy(x, y); c_putc(' ');
		}
	}

	// draw corners
	c_gotoxy(x1, y1); c_putc(0xC9); // top left
	c_gotoxy(x1, y2); c_putc(0xC8); // bottom left
	c_gotoxy(x2, y1); c_putc(0xBB); // top right
	c_gotoxy(x2, y2); c_putc(0xBC); // bottom right
	
	for (x = x1 + 1; x < x2; x++) {
		c_gotoxy(x, y1); c_putc(0xCD); //horiz
		c_gotoxy(x, y2); c_putc(0xCD);
	}
	
	for (y = y1 + 1; y < y2; y++) {
		c_gotoxy(x1, y); c_putc(0xBA); // vert
		c_gotoxy(x2, y); c_putc(0xBA);
	}
	
	*console_x = *console_tx;
	*console_y = *console_ty;
}

c_boxmsg(unsigned x1, unsigned y1, char *msg) {
	unsigned n;
	
	n = strlen(msg) + 3;
	
	c_box(x1, y1, x1 + n, y1 + 2);
	c_gotoxy(x1 + 2, y1 + 1);
	c_puts(msg);
	*console_x = *console_tx;
	*console_y = *console_ty;
}

c_boxquery(unsigned x1, unsigned y1, char *msg, char *dst, unsigned len) {
	unsigned n;
	
	n = strlen(msg) + 3 + len;
	
	c_box(x1, y1, x1 + n, y1 + 2);
	c_gotoxy(x1 + 2, y1 + 1);
	c_puts(msg);
	c_gets(dst, len);
	*console_x = *console_tx;
	*console_y = *console_ty;
}

#endif
