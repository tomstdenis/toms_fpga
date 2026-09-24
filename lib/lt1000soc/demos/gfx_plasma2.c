#include "lt1000.h"

#define SCREEN_WIDTH   320
#define SCREEN_HEIGHT  200
#define FB_SIZE        (SCREEN_WIDTH * SCREEN_HEIGHT)

static uint8_t *VGA_BACK_BUFFER;

// Tunnel lookup tables (320x200 = 64KB)
static uint8_t sum_lut[SCREEN_HEIGHT][SCREEN_WIDTH];

// Pre-generated 256-color RGB332 palette table
static uint8_t palette[256];

// Fixed-point sine table (256 entries)
static const int8_t sin_table[256] = {
      0,   3,   6,   9,  12,  15,  18,  21,  24,  27,  30,  33,  36,  39,  42,  45,
     48,  51,  54,  57,  60,  63,  65,  68,  71,  73,  76,  78,  81,  83,  85,  88,
     90,  92,  94,  96,  98, 100, 102, 104, 106, 107, 109, 111, 112, 113, 115, 116,
    117, 118, 119, 120, 121, 122, 122, 123, 124, 124, 125, 125, 125, 126, 126, 126,
    126, 126, 126, 126, 125, 125, 125, 124, 124, 123, 122, 122, 121, 120, 119, 118,
    117, 116, 115, 113, 112, 111, 109, 107, 106, 104, 102, 100,  98,  96,  94,  92,
     90,  88,  85,  83,  81,  78,  76,  73,  71,  68,  65,  63,  60,  57,  54,  51,
     48,  45,  42,  39,  36,  33,  30,  27,  24,  21,  18,  15,  12,   9,   6,   3,
      0,  -3,  -6,  -9, -12, -15, -18, -21, -24, -27, -30, -33, -36, -39, -42, -45,
    -48, -51, -54, -57, -60, -63, -65, -68, -71, -73, -76, -78, -81, -83, -85, -88,
    -90, -92, -94, -96, -98,-100,-102,-104,-106,-107,-109,-111,-112,-113,-115,-116,
   -117,-118,-119,-120,-121,-122,-122,-123,-124,-124,-125,-125,-125,-126,-126,-126,
   -126,-126,-126,-126,-125,-125,-125,-124,-124,-123,-122,-122,-121,-120,-119,-118,
   -117,-116,-115,-113,-112,-111,-109,-107,-106,-104,-102,-100, -98, -96, -94, -92,
    -90, -88, -85, -83, -81, -78, -76, -73, -71, -68, -65, -63, -60, -57, -54, -51,
    -48, -45, -42, -39, -36, -33, -30, -27, -21, -18, -15, -12,  -9,  -6,  -3
};

static inline uint8_t rgb332(uint8_t r, uint8_t g, uint8_t b) {
    return ((r & 0x07) << 5) | ((g & 0x07) << 2) | (b & 0x03);
}

static uint32_t isqrt(uint32_t n) {
    uint32_t root = 0;
    uint32_t bit = 1UL << 30;
    while (bit > n) bit >>= 2;
    while (bit != 0) {
        if (n >= root + bit) {
            n -= root + bit;
            root = (root >> 1) + bit;
        } else {
            root >>= 1;
        }
        bit >>= 2;
    }
    return root;
}

static uint8_t fast_atan2(int32_t y, int32_t x) {
    if (x == 0 && y == 0) return 0;
    int32_t abs_y = y < 0 ? -y : y;
    int32_t angle;
    if (x >= 0) {
        angle = 32 - (32 * (x - abs_y)) / (x + abs_y + 1);
    } else {
        angle = 96 - (32 * (x + abs_y)) / (abs_y - x + 1);
    }
    if (y < 0) return (uint8_t)(-angle);
    return (uint8_t)angle;
}

static void init_demo_tables(void) {
    int center_x = SCREEN_WIDTH / 2;
    int center_y = SCREEN_HEIGHT / 2;

    // 1. Populate Tunnel LUTs
    for (int y = 0; y < SCREEN_HEIGHT; y++) {
        int dy = y - center_y;
        for (int x = 0; x < SCREEN_WIDTH; x++) {
            int dx = x - center_x;

            uint32_t dist = isqrt((dx * dx) + (dy * dy));
            if (dist == 0) dist = 1;

            uint32_t depth = (32 * 256) / dist;
            sum_lut[y][x] = (uint8_t)(depth & 0xFF) + fast_atan2(dy, dx);
        }
    }

    // 2. Pre-generate smooth 256-entry RGB332 Palette
    for (int i = 0; i < 256; i++) {
        uint8_t r = ((sin_table[i] >> 4) + 4) & 0x07;
        uint8_t g = ((sin_table[(i + 85) & 0xFF] >> 4) + 4) & 0x07;
        uint8_t b = ((sin_table[(i + 170) & 0xFF] >> 5) + 2) & 0x03;
        palette[i] = rgb332(r, g, b);
    }
}

static uint8_t anim_u = 0;
static uint8_t anim_v = 0;

TCM_FUNC(render_tunnel_fast) static void render_tunnel_fast(void) {
    uint8_t *buf = VGA_BACK_BUFFER;

    anim_u += 1;
    anim_v += 2;

    // Direct pointer walking across flat arrays
    const uint8_t *sum_ptr = &sum_lut[0][0];

    for (int i = 0; i < FB_SIZE; i++) {
		// insert periodic yields
		if (!(i & 0xFF)) { yield(); }

        // Fast index calculation: combine pre-calculated depth + angle
        uint8_t color_idx = (sum_ptr[i] + anim_u + anim_v);
        
        // Single lookup directly into the RGB332 palette table
        buf[i] = palette[color_idx];
    }
}

static uint32_t frames = 0;
static void fps_counter(uint32_t data) {
    putstr("\r\nFPS: "); puts_dec(frames);
    frames = 0;
}

static void timer_250msec(uint32_t data) {
    uint32_t d = GPIO_DATA;
    d = (d << 1) | (d >> 31);
    GPIO_DATA = d;
}   

static void uart_handler(uint32_t data) {
    if (UART_STATUS & UART_STATUS_RX_READY) {
        uint32_t v = UART_DATA;
        UART_DATA = v;
        if (v == 27) { // ESC key
            exit(0);
        }
    }
}   

int main(void) {
    setvbuf(stdout, NULL, _IONBF, 0);

    VGA_BACK_BUFFER = (uint8_t *)VGA_ADDR + 0x10000;
    gfx_set_mode(1);

    GPIO_DATA = ~1UL;
    GPIO_OE   = 0xFFFFFFFF;

    init_demo_tables();

    yield_sei();
    yield_add_irq(YIELD_IRQ_TIMER, 1000000UL * yield_usec_to_cycles(), 0, fps_counter);
    yield_add_irq(YIELD_IRQ_TIMER, 250UL * 1000UL * yield_usec_to_cycles(), 0, timer_250msec);
    yield_add_irq(YIELD_IRQ_UART_RX_READY, 0, 0, uart_handler);

    while (1) {
		render_tunnel_fast();
		gfx_vsync();
		VGA_CTRL ^= VGA_CTRL_PAGE_SEL;
		VGA_BACK_BUFFER = ((intptr_t)VGA_BACK_BUFFER) ^ 0x10000;
		++frames;
        yield();
    }

    return 0;
}
