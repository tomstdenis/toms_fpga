#ifdef APPLE2_KBD_BASE

// The KBD as used by Apple 2
extern uint16_t apple2_textmode_addr;
extern uint8_t apple2_textmode, apple2_mixedmode;

#if defined(TRACE) && defined(HOSTPC)
#include <stdio.h>
#define LOG printf
#else
#define LOG(...)
#endif

#ifdef HOSTPC
#include <ncurses.h>
#include <stdio.h>
#include <ctype.h>

static uint8_t kbd_latch = 0x00; // Stores (ASCII | 0x80)

// Call this in your main loop once per frame
void update_host_input() {
    int ch = getch();
    if (ch != ERR) {
        if (ch == '\n' || ch == '\r') ch = 0x0D; // CR
        else if (ch == KEY_F(1)) ch = 3; // BREAK 
        else if (ch == KEY_F(2)) ch = 2; // WARM START
        else if (ch == KEY_F(3)) cpu_int(CPU_SIG_RESET);
        else ch = toupper(ch);
        kbd_latch = ch | 0x80; // Set high bit (Strobe)
    }
}

uint8_t read_apple2_kbd(uint16_t addr) {
	update_host_input();
    switch (addr & 0xFF) { // Masking for 0xC0xx
        case 0x00: 
            return kbd_latch; // Bit 7 stays high until $C010 accessed
        case 0x10: 
            kbd_latch &= 0x7F; // Clear Bit 7 (The "Strobe")
            return 0x00;       // Data returned doesn't matter much
		case 0x30: // SPK
			return 0xFF;
		case 0x50: apple2_textmode = 0; break; //TEXTOFF
		case 0x51: apple2_textmode = 1; break; //TEXTON
		case 0x52: apple2_mixedmode = 0; break; //MIXEDOFF
		case 0x53: apple2_mixedmode = 1; break; //MIXEDON
		case 0x54: apple2_textmode_addr = 0x400; break;
		case 0x55: apple2_textmode_addr = 0x800; break;
    }
    return 0;
}

void write_apple2_kbd(uint16_t addr, uint8_t data)
{
    switch (addr) {
		// strobe signal
        case 0x10:
			kbd_latch &= 0x7F; // clear bit 7 of the strobe
            break;
		case 0x50: apple2_textmode = 0; break; //TEXTOFF
		case 0x51: apple2_textmode = 1; break; //TEXTON
		case 0x52: apple2_mixedmode = 0; break; //MIXEDOFF
		case 0x53: apple2_mixedmode = 1; break; //MIXEDON
		case 0x54: apple2_textmode_addr = 0x400; break;
		case 0x55: apple2_textmode_addr = 0x800; break;
    }
}

#else

static uint8_t kbd_latch = 0x00; // Stores (ASCII | 0x80)

void update_host_input() {
	if (Serial.available()) {
		int ch = Serial.read();
		if (ch == '\n' || ch == '\r') ch = 0x0D; // CR
		else ch = toupper(ch);
		kbd_latch = ch | 0x80; // Set high bit (Strobe)
	}
}

uint8_t read_apple2_kbd(uint16_t addr) {
	update_host_input();
    switch (addr & 0xFF) { // Masking for 0xC0xx
        case 0x00: 
            return kbd_latch; // Bit 7 stays high until $C010 accessed
        case 0x10: 
            kbd_latch &= 0x7F; // Clear Bit 7 (The "Strobe")
            return 0x00;       // Data returned doesn't matter much
		case 0x30: // SPK
			return 0xFF;
		case 0x50: apple2_textmode = 0; break; //TEXTOFF
		case 0x51: apple2_textmode = 1; break; //TEXTON
		case 0x52: apple2_mixedmode = 0; break; //MIXEDOFF
		case 0x53: apple2_mixedmode = 1; break; //MIXEDON
		case 0x54: apple2_textmode_addr = 0x400; break;
		case 0x55: apple2_textmode_addr = 0x800; break;
    }
    return 0;
}

void write_apple2_kbd(uint16_t addr, uint8_t data)
{
    switch (addr) {
		// strobe signal
        case 0x10:
			kbd_latch &= 0x7F; // clear bit 7 of the strobe
            break;
		case 0x50: apple2_textmode = 0; break; //TEXTOFF
		case 0x51: apple2_textmode = 1; break; //TEXTON
		case 0x52: apple2_mixedmode = 0; break; //MIXEDOFF
		case 0x53: apple2_mixedmode = 1; break; //MIXEDON
		case 0x54: apple2_textmode_addr = 0x400; break;
		case 0x55: apple2_textmode_addr = 0x800; break;
    }
}

#endif

#endif
