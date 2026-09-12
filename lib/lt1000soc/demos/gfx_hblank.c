#include <stdint.h>

#define VGA_FB8             ((volatile uint8_t  *)0x04000000)
#define VGA_FB32            ((volatile uint32_t *)0x04000000)
#define VGA_CTRL            ((volatile uint32_t *)0x10000020)

#define WIDTH               320
#define HEIGHT              200
#define PAGE_SIZE           0x10000 

#define CTRL_MODE_GFX       (1 << 0)
#define CTRL_PAGE_1         (1 << 1)
#define CTRL_VBLANK         (1 << 3)
#define CTRL_HBLANK         (1 << 2) // Assuming Bit 2 reflects HBLANK status

static inline void wait_vblank(void) {
    while (!(*VGA_CTRL & CTRL_VBLANK));
}

static inline void wait_vblank_end(void) {
    while (*VGA_CTRL & CTRL_VBLANK);
}

static inline void wait_hblank_pulse(void) {
    while (!(*VGA_CTRL & CTRL_HBLANK));
    while (*VGA_CTRL & CTRL_HBLANK);
}

void draw_page_0_pattern(uint8_t shift) {
    volatile uint8_t *page0 = VGA_FB8;
    for (int y = 0; y < HEIGHT; y++) {
        uint8_t color = (y + shift) & 0x3F;
        for (int x = 0; x < WIDTH; x++) {
            page0[y * WIDTH + x] = color;
        }
    }
}

void draw_page_1_pattern(uint8_t shift) {
    volatile uint8_t *page1 = VGA_FB8 + PAGE_SIZE;
    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            uint8_t grid = (((x + shift) >> 4) ^ ((y + shift) >> 4)) & 1;
            page1[y * WIDTH + x] = grid ? 0b11111111 : 0b00000011;
        }
    }
}

void main(void) {
    uint8_t frame_counter = 0;
    int target = 200, dy = 1;

    // Set graphics mode initially on Page 0
    *VGA_CTRL = CTRL_MODE_GFX;

	// Update independent framebuffers
	draw_page_0_pattern(frame_counter);
	draw_page_1_pattern(frame_counter);

    while (1) {

        // 1. Sync to start of active frame display
        wait_vblank();
        wait_vblank_end();

        // 2. Count 100 HBLANK pulses to hit exact middle of screen (Y = 100)
        // Adjust scanline offset to match your VGA IP's porch timing!
        for (int line = 0; line < target; line++) {
            wait_hblank_pulse();
        }
        
        target += dy;
        if (target == 250) dy = -1;
        if (target == 150) dy = 1;

        // 3. MID-FRAME FLIP: Force Page 1 display for bottom half of monitor
        *VGA_CTRL = CTRL_MODE_GFX | CTRL_PAGE_1;

        // 4. Wait for frame to finish in VBLANK, then reset to Page 0 for top half
        wait_vblank();
        *VGA_CTRL = CTRL_MODE_GFX;

        frame_counter++;
    }
}
