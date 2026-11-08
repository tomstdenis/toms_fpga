#ifdef APPLE1_PIA_BASE

// The PIA as used by Apple 1

#if defined(TRACE) && defined(HOSTPC)
#include <stdio.h>
#define LOG printf
#else
#define LOG(...)
#endif

#ifdef HOSTPC
#include <stdio.h>
#include <ctype.h>
#include <ncurses.h>

uint8_t read_apple1_pia(uint16_t addr)
{
    int ch;
    switch (addr) {
        case 0x10: // KBD (Keyboard Data)
            ch = getch();
            if (ch == ERR) return 0;

            // Apple 1 expects CR (\r), ncurses usually returns \n for Enter
            if (ch == '\n' || ch == '\r') ch = '\r';

            // The Apple 1 KBD register returns ASCII with bit 7 high
            return (uint8_t)(toupper(ch) | 0x80);
            
        case 0x11: // KBDCR (Control Register / Status)
            ch = getch();
            if (ch != ERR) {
                ungetch(ch); // Put it back in the ncurses buffer
                return 0x80; // Bit 7 high = Key pressed
            }
            return 0x00;     // No key pressed
    }
    return 0;
}

void write_apple1_pia(uint16_t addr, uint8_t data)
{
    switch (addr) {
        case 0x12: // DSP (Display Data)
            data &= 0x7F; // Apple 1 uses 7-bit ASCII
            if (data == '\r') {
                addch('\n');
            } else if (data != '\n') { // apple1 apps seem to send \r or \r\n either way let's just map both to a single \n
                addch(data);
            }
            refresh(); // Ensure the character appears on screen
            break;
    }
}

#else

uint8_t read_apple1_pia(uint16_t addr)
{
    int ch;
    switch (addr) {
        case 0x10: // KBD (Keyboard Data)
			if (Serial.available() == 0) return 0;
            ch = Serial.read();
            
            // Apple 1 expects CR (\r), ncurses usually returns \n for Enter
            if (ch == '\n' || ch == '\r') ch = '\r';

            // The Apple 1 KBD register returns ASCII with bit 7 high
            return (uint8_t)(toupper(ch) | 0x80);
            
        case 0x11: // KBDCR (Control Register / Status)
			if (Serial.available()) return 0x80;
			return 0x00;
    }
    return 0;
}

void write_apple1_pia(uint16_t addr, uint8_t data)
{
    switch (addr) {
        case 0x12: // DSP (Display Data)
            data &= 0x7F; // Apple 1 uses 7-bit ASCII
            if (data == '\r') {
                Serial.write('\n');
            } else if (data != '\n') { // apple1 apps seem to send \r or \r\n either way let's just map both to a single \n
                Serial.write(data);
            }
            break;
    }
}

#endif

#endif
