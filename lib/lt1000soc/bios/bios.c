#include <stdint.h>

#define VGA_FB        ((volatile uint8_t  *)0x04000000)
#define VGA_FB32      ((volatile uint32_t *)0x04000000)
#define VGA_CTRL      ((volatile uint32_t *)0x10000020)

// PSRAM (nanosram + 8KB nanocache mapped at 0x08000000)
#define PSRAM_BASE8   ((volatile uint8_t  *)0x08000000)
#define PSRAM_BASE32  ((volatile uint32_t *)0x08000000)

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
        stars[i].color = (stars[i].speed == 3) ? 0xFF : ((stars[i].speed == 2) ? 0x92 : 0x49);
    }
}

void bios_main(void) {
    uint8_t active_page = 0;
    *VGA_CTRL = CTRL_MODE_GFX | (active_page ? CTRL_PAGE_1 : 0);

    init_stars();

    uint8_t angle = 0;
    uint8_t pulse = 0;

    // Off-screen canvas in PSRAM (uses 64KB starting at address 0x08000000)
    volatile uint8_t  *psram_canvas   = PSRAM_BASE8;
    volatile uint32_t *psram_canvas32 = PSRAM_BASE32;

    while (1) {
        // VGA target frame buffer pointers
        uint32_t back_page_offset = (active_page == 0) ? 0x10000 : 0x00000;
        volatile uint32_t *vga_back_buffer32 = VGA_FB32 + (back_page_offset / 4);

        // -------------------------------------------------------------
        // STEP 1: Render scene into PSRAM (0x08000000)
        // -------------------------------------------------------------

        // Clear PSRAM via 32-bit writes (Tests PSRAM burst writes + cache fills)
        for (int i = 0; i < (WIDTH * HEIGHT) / 4; i++) {
            psram_canvas32[i] = 0x00000000;
        }

        // Render Starfield directly into PSRAM using 8-bit byte writes
        for (int i = 0; i < NUM_STARS; i++) {
            stars[i].x -= stars[i].speed;
            if (stars[i].x < 0) {
                stars[i].x = WIDTH - 1;
                stars[i].y = rand_fast() % HEIGHT;
            }
            psram_canvas[stars[i].y * WIDTH + stars[i].x] = stars[i].color;
        }

        // Render Color Wheel into PSRAM
        int16_t center_x = 160 + (cos8(angle) / 4);
        int16_t center_y = 100 + (sin8(angle) / 4);
        int16_t radius   = 35  + (sin8(pulse) / 4);
        int32_t r2       = radius * radius;

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

                    uint8_t r2bit = ((uint32_t)(dx + radius) * inv_diameter_64col) >> 16;
                    uint8_t g2bit = ((uint32_t)y_factor * inv_diameter_64col) >> 16;
                    uint8_t b2bit = (r2bit ^ g2bit) & 0x03;

                    r2bit = (r2bit + (angle >> 6)) & 0x03;
                    g2bit = (g2bit + (pulse >> 6)) & 0x03;

                    uint8_t pixel_332 = ((r2bit << 1) << 5) | ((g2bit << 1) << 2) | b2bit;

                    // Write 8-bit pixel directly to PSRAM
                    psram_canvas[row_offset + px] = pixel_332;
                }
            }
        }

        // -------------------------------------------------------------
        // STEP 2: Blit PSRAM -> VGA Frame Buffer (0x04000000)
        // -------------------------------------------------------------
        // Reads finished frame from PSRAM cache, streams directly to VGA
        for (int i = 0; i < (WIDTH * HEIGHT) / 4; i++) {
            vga_back_buffer32[i] = psram_canvas32[i];
        }

        // --- Swap & Sync ---
        wait_vblank();

        active_page = !active_page;
        *VGA_CTRL = CTRL_MODE_GFX | (active_page ? CTRL_PAGE_1 : 0);

        angle += 2;
        pulse += 3;

        delay_short(1000);
    }
}
