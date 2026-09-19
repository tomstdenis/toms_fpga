#ifndef LT1000_SERIAL_H
#define LT1000_SERIAL_H

int getch(void);
char *getstr(char *s);
void putch(const char c);	
void putstr(const char *s);
void puts_hex(uint32_t v, int width);
void puts_dec(uint32_t v);

#endif
