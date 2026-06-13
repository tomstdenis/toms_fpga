#define vidmem ((unsigned char *)0xF800)

// store console variables at end of vidmem
// this leaves the main 60K block totally free for
// the app
#define console_x ((unsigned *)(0xFFFE))
#define console_y ((unsigned *)(0xFFFC))

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
	} while (ch = 0xFFFF);
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
			if (ch == '\n') {
				break;
			} else {
				if (s != on) {
					*s++ = ch;
					c_putc(ch);
				}
			}
		}
	}
	*s = 0;
}
