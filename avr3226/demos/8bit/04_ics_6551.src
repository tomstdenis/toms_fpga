#ifdef ACIA6551_BASE

// ACIA 6551 8-bit UART

#ifdef HOSTPC
#include <stdio.h>
#include <ctype.h>
#include <ncurses.h>

// read from one of the 4 byte regs
uint8_t read_6551(uint16_t addr)
{
	int ch;
	switch (addr) {
		case 0:
			ch = getch();
			if (ch == ERR) return 0;
			return toupper(ch);
		case 1:
			ch = getch();
			if (ch == ERR) return 0;
			return 0x08;
	}
	return 0;
}

// write to one of the 4 byte regs
void write_6551(uint16_t addr, uint8_t data)
{
	switch (addr) {
		case 0: // DATA
			if (data == '\r') {
				addch('\n');
			} else if (data != '\n') {
				addch(data);
			}
			break;
	}
}

#else

// read from one of the 4 byte regs
uint8_t read_6551(uint16_t addr)
{
	switch (addr) {
		case 0:
			return Serial.read();
		case 1:
			return Serial.available() ? 0x08 : 0x00;
	}
	return 0;
}

// write to one of the 4 byte regs
void write_6551(uint16_t addr, uint8_t data)
{
	switch (addr) {
		case 0: // DATA
			if (data == '\r') {
				Serial.write('\n');
			} else if (data != '\n') {
				Serial.write(data);
			}
			break;
		case 3: // CTL
			break;
	}
}

#endif

#endif
