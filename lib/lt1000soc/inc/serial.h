#ifndef LT1000_SERIAL_H
#define LT1000_SERIAL_H

char getc(void);
void putc(const char c);	
void puts(const char *s);
void puts_hex(uint32_t v, int width);

#endif
