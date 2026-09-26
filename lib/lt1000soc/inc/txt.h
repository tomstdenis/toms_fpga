#ifndef LT1000_TXT_H
#define LT1000_TXT_H

#define TXT_ROWS 50
#define TXT_COLS 80

void txt_init(void);
void txt_cursor(uint32_t x, uint32_t y, uint32_t col);
void txt_clrscr(void);
void txt_scroll(void);
void txt_putc(char c);
void txt_puts(char *s);
char *txt_gets(char *s);
void txt_vprintf(const char *fmt, va_list args);
void txt_printf(const char *fmt, ...);

#endif
