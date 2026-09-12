#include <stdint.h>

#define UART_DATA           ((volatile uint32_t *)0x10000018)
#define UART_STATUS         ((volatile uint32_t *)0x1000001C)
#define UART_STATUS_RX_READY 4

#define VGA_FB              ((volatile uint8_t  *)0x04000000)
#define VGA_FB32            ((volatile uint32_t *)0x04000000)
#define VGA_CTRL            ((volatile uint32_t *)0x10000020)

#define PSRAM_BASE8         ((volatile uint8_t  *)0x08010000)
#define PSRAM_BASE32        ((volatile uint32_t *)0x08010000)

#define WIDTH               320
#define HEIGHT              200
#define PAGE_SIZE           0x10000 

#define CTRL_MODE_GFX       (1 << 0)
#define CTRL_PAGE_1         (1 << 1)
#define CTRL_VBLANK         (1 << 3)

static inline uint32_t rdcycle(void) {
    uint32_t c;
    __asm__ volatile ("rdcycle %0" : "=r"(c));
    return c;
}

static void wait_vblank(void) {
    while (!(*VGA_CTRL & CTRL_VBLANK));
}

static int8_t sin8(uint8_t angle) {
    static const uint8_t sin_table[65] = {
          0,   3,   6,   9,  12,  15,  18,  21,  24,  27,  30,  33,  36,  39,  42,  45,
         48,  51,  54,  57,  60,  63,  65,  68,  71,  73,  76,  78,  81,  83,  85,  88,
         90,  92,  94,  96,  98, 100, 102, 104, 106, 107, 109, 111, 112, 113, 115, 116,
        117, 118, 119, 120, 121, 122, 123, 124, 124, 125, 125, 126, 126, 126, 126, 126, 127
    };
    uint8_t idx = angle & 0x3F;
    if ((angle & 0x40) != 0) idx = 64 - idx;
    uint8_t val = sin_table[idx];
    return ((angle & 0x80) != 0) ? -val : val;
}

// 8x8 Sprite Bob ("LT" for LT1000)
static const uint8_t bob_sprite[8] = {
    0b11000111,
    0b11000111,
		0b11000001,
    0b11000001,
    0b11000001,
    0b11000001,
    0b11110001,
    0b11110001
};

void main(void)
{
    uint8_t active_page = 0;
    *VGA_CTRL = CTRL_MODE_GFX | (active_page ? CTRL_PAGE_1 : 0);

    uint8_t pos1 = 0, pos2 = 0;
    uint8_t bob_angle_x = 0, bob_angle_y = 0;

    volatile uint8_t  *psram_canvas   = PSRAM_BASE8;
    volatile uint32_t *psram_canvas32 = PSRAM_BASE32;

    while (1) {
        uint32_t back_page_offset = (active_page == 0) ? PAGE_SIZE : 0x00000;
        volatile uint32_t *vga_back_buffer32 = VGA_FB32 + (back_page_offset / 4);

		// 1. Render Waving Copper Bars into PSRAM Scanlines
		uint8_t a1 = pos1;
		uint8_t a2 = pos2;

		for (int y = 0; y < HEIGHT; y++) {
			int16_t wave1 = sin8(a1); // -127 to +127
			int16_t wave2 = sin8(a2); // -127 to +127
			
			// Scale 0..255 range properly across available bit-widths
			uint8_t r = ((wave1 + 128) >> 5) & 0x07; // Full 0..7 range (3 bits)
			uint8_t g = ((wave2 + 128) >> 5) & 0x07; // Full 0..7 range (3 bits)
			uint8_t b = ((wave1 + wave2 + 254) >> 7) & 0x03; // Full 0..3 range (2 bits)
			
			// Assemble standard RGB332 byte: [RRR GGG BB]
			uint8_t color = (r << 5) | (g << 2) | b;
			
			// Pack byte color into 32-bit DWORD (4 identical pixels)
			uint32_t color32 = color | (color << 8) | (color << 16) | (color << 24);

			uint32_t row_dword_offset = (y * WIDTH) / 4;
			for (int x = 0; x < WIDTH / 4; x++) {
				psram_canvas32[row_dword_offset + x] = color32;
			}

			a1 += 3;
			a2 += 2;
		}
        // 2. Draw Bouncing Sprite Bob over PSRAM canvas
        int16_t bob_x = 156 + (sin8(bob_angle_x) * 120 / 128);
        int16_t bob_y = 96  + (sin8(bob_angle_y) * 80  / 128);

        for (int sy = 0; sy < 8; sy++) {
            int16_t py = bob_y + sy;
            if (py < 0 || py >= HEIGHT) continue;

            uint8_t row_bits = bob_sprite[sy];
            for (int sx = 0; sx < 8; sx++) {
                int16_t px = bob_x + sx;
                if (px < 0 || px >= WIDTH) continue;

                // If bit set, draw bright yellow (0xFC) pixel
                if (row_bits & (1 << (7 - sx))) {
                    psram_canvas[py * WIDTH + px] = 0xFC;
                }
            }
        }

        // 3. Blit PSRAM -> VGA Back Buffer (32-bit transfer pass)
        for (int i = 0; i < (WIDTH * HEIGHT) / 4; i++) {
            vga_back_buffer32[i] = psram_canvas32[i];
        }

        // 4. Swap & Sync
        wait_vblank();
        active_page = !active_page;
        *VGA_CTRL = CTRL_MODE_GFX | (active_page ? CTRL_PAGE_1 : 0);

        pos1 += 4;
        pos2 += 2;
        bob_angle_x += 3;
        bob_angle_y += 5;

        // UART Echo Loop
        if (*UART_STATUS & UART_STATUS_RX_READY) {
            *UART_DATA = *UART_DATA;
        }
    }
}
