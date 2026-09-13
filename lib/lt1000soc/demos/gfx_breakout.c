#include <stdint.h>

#define UART_DATA           ((volatile uint32_t *)0x10000018)
#define UART_STATUS         ((volatile uint32_t *)0x1000001C)
#define UART_STATUS_TX_FULL  1
#define UART_STATUS_TX_EMPTY 2
#define UART_STATUS_RX_READY 4

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

#define BRICK_ROWS          8
#define BRICK_COLS          10
#define BRICK_W             28
#define BRICK_H             8
#define BRICK_TOP           20
#define BRICK_LEFT          20

#define TRAIL_LEN           6

typedef struct {
    int16_t x, y;
} Pos2D;

static void wait_vblank(void) {
    while (!(*VGA_CTRL & CTRL_VBLANK));
}

// Simple LFSR pseudo-random generator
static uint16_t lfsr = 0xACE1;
static uint16_t rand_u16(void) {
    uint16_t bit = ((lfsr >> 0) ^ (lfsr >> 2) ^ (lfsr >> 3) ^ (lfsr >> 5)) & 1;
    lfsr = (lfsr >> 1) | (bit << 15);
    return lfsr;
}

// Solid 8-bit color palette definitions
static const uint8_t row_colors[BRICK_ROWS] = {
    0b11000000, // Bright Red
    0b11011000, // Orange
    0b11110000, // Yellow
    0b00110000, // Bright Green
    0b00111100, // Cyan
    0b00000011, // Blue
    0b11000011, // Magenta
    0b11111111  // White
};

// Color gradient for the 6-pixel ball trail (Bright -> Dim)
static const uint8_t trail_colors[TRAIL_LEN] = {
    0b11111111, // Head: White
    0b11111100, // Yellow
    0b11011000, // Orange
    0b11000000, // Red
    0b01000000, // Dark Red
    0b00100000  // Dim Red
};

// Game State
static uint8_t bricks[BRICK_ROWS][BRICK_COLS];

static void init_bricks(volatile uint8_t *canvas) {
    for (int r = 0; r < BRICK_ROWS; r++) {
        for (int c = 0; c < BRICK_COLS; c++) {
            bricks[r][c] = row_colors[r];
        }
    }
}

static inline void draw_rect(volatile uint8_t *canvas, int16_t rx, int16_t ry, int16_t rw, int16_t rh, uint8_t color) {
    if (rx < 0 || ry < 0 || rx + rw > WIDTH || ry + rh > HEIGHT) return;
    
    for (int16_t y = ry; y < ry + rh; y++) {
        volatile uint8_t *ptr = canvas + (y * WIDTH + rx);
        int16_t count = rw;
        
        while (((uintptr_t)ptr & 3) && count > 0) {
            *ptr++ = color;
            count--;
        }
        if (count >= 4) {
            uint32_t color32 = (uint32_t)color | ((uint32_t)color << 8) |
                               ((uint32_t)color << 16) | ((uint32_t)color << 24);
            volatile uint32_t *ptr32 = (volatile uint32_t *)ptr;
            int16_t dwords = count >> 2;
            while (dwords--) *ptr32++ = color32;
            ptr = (volatile uint8_t *)ptr32;
            count &= 3;
        }
        while (count > 0) {
            *ptr++ = color;
            count--;
        }
    }
}

void main(void) {
    uint8_t active_page = 0;
    *VGA_CTRL = CTRL_MODE_GFX | (active_page ? CTRL_PAGE_1 : 0);

    volatile uint8_t  *psram_canvas   = PSRAM_BASE8;
    volatile uint32_t *psram_canvas32 = PSRAM_BASE32;

    // Full clear canvas once on startup
    for (int i = 0; i < (WIDTH * HEIGHT) / 4; i++) {
        psram_canvas32[i] = 0;
    }

    init_bricks(psram_canvas);

    // Ball state (Q4 fixed-point)
    int16_t ball_x = 160 << 4;
    int16_t ball_y = 120 << 4;
    int16_t ball_dx = 24;
    int16_t ball_dy = -32;
    const int16_t ball_size = 4;

    // Trail ring buffer
    Pos2D ball_trail[TRAIL_LEN];
    for (int i = 0; i < TRAIL_LEN; i++) {
        ball_trail[i].x = 160;
        ball_trail[i].y = 120;
    }
    uint8_t trail_head = 0;

    // Paddle state
    int16_t paddle_w = 40;
    int16_t paddle_h = 6;
    int16_t paddle_x = 140;
    int16_t old_paddle_x = 140;
    const int16_t paddle_y = 185;

    while (1) {
        uint32_t back_page_offset = (active_page == 0) ? PAGE_SIZE : 0x00000;
        volatile uint32_t *vga_back_buffer32 = VGA_FB32 + (back_page_offset / 4);

        // 1. Erase oldest ball trail segment
        uint8_t tail_idx = (trail_head + 1) % TRAIL_LEN;
        draw_rect(psram_canvas, ball_trail[tail_idx].x, ball_trail[tail_idx].y, ball_size, ball_size, 0x00);

        // 2. Erase old paddle position
        if (old_paddle_x != paddle_x) {
            draw_rect(psram_canvas, old_paddle_x, paddle_y, paddle_w, paddle_h, 0x00);
            old_paddle_x = paddle_x;
        }

        // 3. AI Paddle Movement
        int16_t bx = ball_x >> 4;
        int16_t by = ball_y >> 4;
        int16_t target_paddle_x = bx - (paddle_w / 2);

        if (paddle_x < target_paddle_x) {
            paddle_x += 3;
        } else if (paddle_x > target_paddle_x) {
            paddle_x -= 3;
        }

        if (paddle_x < 0) paddle_x = 0;
        if (paddle_x > WIDTH - paddle_w) paddle_x = WIDTH - paddle_w;

        // 4. Move Ball & Collisions
        ball_x += ball_dx;
        ball_y += ball_dy;
        bx = ball_x >> 4;
        by = ball_y >> 4;

        if (bx <= 0) {
            ball_x = 0;
            ball_dx = -ball_dx;
        } else if (bx >= WIDTH - ball_size) {
            ball_x = (WIDTH - ball_size) << 4;
            ball_dx = -ball_dx;
        }

        if (by <= 0) {
            ball_y = 0;
            ball_dy = -ball_dy;
        } else if (by >= HEIGHT - ball_size) {
            // Reset ball position
            ball_x = 160 << 4;
            ball_y = 100 << 4;
            ball_dx = (rand_u16() & 1) ? 24 : -24;
            ball_dy = -32;

            // Clear canvas & reset bricks
            for (int i = 0; i < (WIDTH * HEIGHT) / 4; i++) psram_canvas32[i] = 0;
            init_bricks(psram_canvas);
        }

        // Paddle Collision
        if (by + ball_size >= paddle_y && by <= paddle_y + paddle_h) {
            if (bx + ball_size >= paddle_x && bx <= paddle_x + paddle_w) {
                ball_dy = -ball_dy;
                ball_y = (paddle_y - ball_size) << 4;

                int16_t hit_pos = (bx + (ball_size / 2)) - (paddle_x + (paddle_w / 2));
                ball_dx += (hit_pos >> 1);
                if (ball_dx > 48) ball_dx = 48;
                if (ball_dx < -48) ball_dx = -48;
            }
        }

        // Brick Collisions
        uint8_t active_bricks = 0;
        for (int r = 0; r < BRICK_ROWS; r++) {
            for (int c = 0; c < BRICK_COLS; c++) {
                if (bricks[r][c] == 0) continue;
                active_bricks++;

                int16_t rx = BRICK_LEFT + c * BRICK_W;
                int16_t ry = BRICK_TOP + r * BRICK_H;

                if (bx + ball_size >= rx && bx <= rx + BRICK_W &&
                    by + ball_size >= ry && by <= ry + BRICK_H) {
                    
                    // Erase brick from canvas
                    draw_rect(psram_canvas, rx, ry, BRICK_W - 2, BRICK_H - 2, 0x00);
                    bricks[r][c] = 0;
                    ball_dy = -ball_dy;
                    break;
                }
            }
        }

        if (active_bricks == 0) {
            for (int i = 0; i < (WIDTH * HEIGHT) / 4; i++) psram_canvas32[i] = 0;
            init_bricks(psram_canvas);
            ball_y = 100 << 4;
            ball_dy = 32;
        }

        // 5. Update Trail History
        trail_head = (trail_head + 1) % TRAIL_LEN;
        ball_trail[trail_head].x = bx;
        ball_trail[trail_head].y = by;

        // 6. Draw Active Bricks
        for (int r = 0; r < BRICK_ROWS; r++) {
            for (int c = 0; c < BRICK_COLS; c++) {
                if (bricks[r][c] != 0) {
                    draw_rect(psram_canvas, BRICK_LEFT + c * BRICK_W, BRICK_TOP + r * BRICK_H, 
                              BRICK_W - 2, BRICK_H - 2, bricks[r][c]);
                }
            }
        }

        // 7. Draw Ball Trail (Back to Front)
        for (int i = 0; i < TRAIL_LEN; i++) {
            uint8_t idx = (trail_head + TRAIL_LEN - i) % TRAIL_LEN;
            draw_rect(psram_canvas, ball_trail[idx].x, ball_trail[idx].y, ball_size, ball_size, trail_colors[i]);
        }

        // 8. Draw Paddle
        draw_rect(psram_canvas, paddle_x, paddle_y, paddle_w, paddle_h, 0b11111111);

        // 9. Blit PSRAM -> VGA Back Buffer
        for (int i = 0; i < (WIDTH * HEIGHT) / 4; i++) {
            vga_back_buffer32[i] = psram_canvas32[i];
        }

        // 10. Page Swap on VBLANK
        wait_vblank();
        active_page = !active_page;
        *VGA_CTRL = CTRL_MODE_GFX | (active_page ? CTRL_PAGE_1 : 0);

        // uart echo
        if (*UART_STATUS & UART_STATUS_RX_READY) {
			uint32_t v = *UART_DATA;
			*UART_DATA = v;
			if (v == 27) { 
				void (*bios_entry)(void) = (void (*)(void))0x01000000;
				bios_entry();
			}
		}
    }
}
