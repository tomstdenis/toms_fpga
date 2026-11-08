#ifdef RISCV_PLATFORM_BASE

// 0x00 - Serial out
// 0x01 - Serial in (blocking)
// 0x02 - poll Serial in
// 0x03 - refresh the display
// 0x04 - move cursor x
// 0x05 - move cursor y


#if defined(HOSTPC)
#include <ncurses.h>
#include <unistd.h>
static int lastch = ERR;

uint8_t read_platform(uint16_t addr)
{
	switch (addr) {
		case 0x01: // read serial in (wait if not avail)
			while (lastch == ERR) {
				lastch = getch();
			} while (lastch == ERR);
			addch(lastch);
			refresh();
			return lastch;
		case 0x02: // return non-zero if char avail
			lastch = getch();
			return (lastch == ERR) ? 0 : 1;
	}
	return 0xFF;
}


void write_platform(uint16_t addr, uint8_t val)
{
	int x, y;
	switch (addr) {
		case 0x00: // write serial out
			addch(val);
			break;
		case 0x03: // refresh()
			refresh();
			break;
		case 0x04: // move x
			getyx(stdscr, y, x);
			move(y, val);
			break;
		case 0x05: // move y
			getyx(stdscr, y, x);
			move(val, x);
			break;
	}
}

#else

uint8_t read_platform(uint16_t addr)
{
	switch (addr) {
		case 0x01: // read serial in (wait if not avail)
			return Serial.read();
		case 0x02: // return non-zero if char avail
			return Serial.available() ? 1 : 0;
	}
	return 0xFF;
}

void write_platform(uint16_t addr, uint8_t val)
{
	switch (addr) {
		case 0x00: // write serial out
			Serial.write(val);
			break;
	}
}

#endif

#endif
