#include <stdint.h>

#define LGR_BASE ((volatile uint8_t*) 0x0400)

#define GRP_OFF     (*(volatile uint8_t*) 0xC050 = 1)
#define MIXED_OFF   (*(volatile uint8_t*) 0xC052 = 1)
#define PAGE_1      (*(volatile uint8_t*) 0xC054 = 1)
#define LORES_ON    (*(volatile uint8_t*) 0xC056 = 1)

const uint16_t row_offsets[48] = {
    0x000, 0x080, 0x100, 0x180, 0x200, 0x280, 0x300, 0x380,
    0x028, 0x0A8, 0x128, 0x1A8, 0x228, 0x2A8, 0x328, 0x3A8,
    0x050, 0x0D0, 0x150, 0x1D0, 0x250, 0x2D0, 0x350, 0x3D0,
    0x078, 0x0F8, 0x178, 0x1F8, 0x278, 0x2F8, 0x378, 0x3F8,
    0x020, 0x0A0, 0x120, 0x1A0, 0x220, 0x2A0, 0x320, 0x3A0,
    0x048, 0x0C8, 0x148, 0x1C8, 0x248, 0x2C8, 0x348, 0x3C8
};

void set_pixel(uint16_t x, uint16_t y, uint8_t color) {
    uint16_t addr;
    uint8_t current;
	
	addr = row_offsets[y] + x;
	current = LGR_BASE[addr];
    
    if (y & 1) {
        // Odd X: upper nibble (bits 4-7)
        LGR_BASE[addr] = (current & 0x0F) | ((color & 0x0F) << 4);
    } else {
        // Even X: lower nibble (bits 0-3)
        LGR_BASE[addr] = (current & 0xF0) | (color & 0x0F);
    }
}

void clear_screen(void) {
    uint16_t i;
    for (i = 0; i < 1024; i++) {
        LGR_BASE[i] = 0;
    }
}

void demo(void) {
    // Start safely in the middle of the screen (X: 20, Y: 24)
    int16_t x = 20 << 4;
    int16_t y = 24 << 4;
    int16_t vx = 2;
    int16_t vy = 3;
    uint8_t color = 9;

    GRP_OFF;
    MIXED_OFF;
    PAGE_1;
    LORES_ON;

    clear_screen();

	for (x = 0; x < 40; x++) {
		set_pixel(x, x, 4);
	}

    while (0) {
		volatile uint16_t d;
        // Clear previous ball position (or let it leave a trail—comment out if you want solid tracking)
        // For clean movement, we update position and redraw:
        
        x += vx;
        y += vy;

        // Correct bounds checking for 0-39 (X) and 0-47 (Y)
        if (x < 0) { x = 0; vx = -vx; color = (color + 1) & 0x0F; }
        if (x > (39 << 4)) { x = 39 << 4; vx = -vx; color = (color + 1) & 0x0F; }

        if (y < 0) { y = 0; vy = -vy; color = (color + 1) & 0x0F; }
        if (y > (47 << 4)) { y = 47 << 4; vy = -vy; color = (color + 1) & 0x0F; }

        set_pixel(x >> 4, y >> 4, color == 0 ? 1 : color);

        // Delay loop to keep the animation visible
        for (d = 0; d < 3000; d++);
    }
}

void main(void)
{
/*
	asm (
		"LDX #$FF\n"
		"TXS\n"
		"JSR _demo"
	);
*/
	demo();
}