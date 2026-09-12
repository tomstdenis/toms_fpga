#include <stdint.h>

#define VGA_FB        ((volatile uint8_t  *)0x04000000)
#define VGA_FB32      ((volatile uint32_t *)0x04000000)
#define VGA_CTRL      ((volatile uint32_t *)0x10000020)

#define WIDTH         320
#define HEIGHT        200
#define PAGE_SIZE     0x10000 // 64KB per page offset

#define MODE_TEXT     0
#define MODE_GFX      1

// Bit definitions for VGA_CTRL
#define CTRL_MODE_GFX (1 << 0)
#define CTRL_PAGE_1   (1 << 1)
#define CTRL_HBLANK   (1 << 2)
#define CTRL_VBLANK   (1 << 3)

static inline void delay_short(volatile uint32_t count) {
    while (count--) {
        __asm__ volatile ("nop");
    }
}

static void wait_vblank(void) {
    while (!(*VGA_CTRL & CTRL_VBLANK));
}

static uint32_t rng_state = 0x12345678;
static uint32_t rand_fast(void) {
    rng_state ^= rng_state << 13;
    rng_state ^= rng_state >> 17;
    rng_state ^= rng_state << 5;
    return rng_state;
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

static inline int8_t cos8(uint8_t angle) {
    return sin8(angle + 64);
}

typedef struct {
    int16_t x, y;
    uint8_t speed;
    uint8_t color;
} Star;

#define NUM_STARS 60
static Star stars[NUM_STARS];

static void init_stars(void) {
    for (int i = 0; i < NUM_STARS; i++) {
        stars[i].x = rand_fast() % WIDTH;
        stars[i].y = rand_fast() % HEIGHT;
        stars[i].speed = (rand_fast() % 3) + 1;
        // Map star colors to top bits of R, G, B for 6-bit DAC visibility
        stars[i].color = (stars[i].speed == 3) ? 0xFF : ((stars[i].speed == 2) ? 0x92 : 0x49);
    }
}

void bios_main(void) {
    // 1. Switch to 320x200 GFX mode, rendering initially to Page 0
    uint8_t active_page = 0;
    *VGA_CTRL = CTRL_MODE_GFX | (active_page ? CTRL_PAGE_1 : 0);

    init_stars();

    uint8_t angle = 0;
    uint8_t pulse = 0;

    while (1) {
        // Render into the BACK buffer (Page 1 if active is 0, Page 0 if active is 1)
        uint32_t back_page_offset = (active_page == 0) ? 0x10000 : 0x00000;
        volatile uint8_t  *back_buffer   = VGA_FB   + back_page_offset;
        volatile uint32_t *back_buffer32 = VGA_FB32 + (back_page_offset / 4);

        // --- Fast 32-bit Clear (Clears visible 320x200 = 64,000 bytes) ---
        for (int i = 0; i < (WIDTH * HEIGHT) / 4; i++) {
            back_buffer32[i] = 0x00000000;
        }

        // --- Render Starfield ---
        for (int i = 0; i < NUM_STARS; i++) {
            stars[i].x -= stars[i].speed;
            if (stars[i].x < 0) {
                stars[i].x = WIDTH - 1;
                stars[i].y = rand_fast() % HEIGHT;
            }
            back_buffer[stars[i].y * WIDTH + stars[i].x] = stars[i].color;
        }

        // --- Render Pulsing Color Wheel (6-Bit / 64-Color DAC Friendly) ---
        int16_t center_x = 160 + (cos8(angle) / 4);
        int16_t center_y = 100 + (sin8(angle) / 4);
        int16_t radius   = 35  + (sin8(pulse) / 4);
        int32_t r2       = radius * radius;

        // Fixed-point scale factor (maps 0..radius*2 range into 0..3 for 2-bit DAC channel depth)
        uint32_t inv_diameter_64col = (3 << 16) / (radius * 2);

        for (int16_t dy = -radius; dy <= radius; dy++) {
            int16_t py = center_y + dy;
            if (py < 0 || py >= HEIGHT) continue;

            int32_t dy2 = dy * dy;
            uint32_t row_offset = py * WIDTH;
            uint16_t y_factor = (dy + radius);

            for (int16_t dx = -radius; dx <= radius; dx++) {
                if ((dx * dx) + dy2 <= r2) {
                    int16_t px = center_x + dx;
                    if (px < 0 || px >= WIDTH) continue;

                    // Calculate 2-bit base channels (range 0..3)
                    uint8_t r2bit = ((uint32_t)(dx + radius) * inv_diameter_64col) >> 16;
                    uint8_t g2bit = ((uint32_t)y_factor * inv_diameter_64col) >> 16;
                    uint8_t b2bit = (r2bit ^ g2bit) & 0x03;

                    // Rotate colors dynamically
                    r2bit = (r2bit + (angle >> 6)) & 0x03;
                    g2bit = (g2bit + (pulse >> 6)) & 0x03;

                    // Pack into 332 format ensuring top bits (6-bit DAC targets) are driven:
                    // RRR -> r2bit << 1 (bits 7,6)
                    // GGG -> g2bit << 1 (bits 4,3)
                    // BB  -> b2bit      (bits 1,0)
                    uint8_t pixel_332 = ((r2bit << 1) << 5) | ((g2bit << 1) << 2) | b2bit;

                    back_buffer[row_offset + px] = pixel_332;
                }
            }
        }

        // --- Swap & Sync ---
        wait_vblank();

        // Display the page we just rendered
        active_page = !active_page;
        *VGA_CTRL = CTRL_MODE_GFX | (active_page ? CTRL_PAGE_1 : 0);

        angle += 2;
        pulse += 3;

        delay_short(10000);
    }
}
