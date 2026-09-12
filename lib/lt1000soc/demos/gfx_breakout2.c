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

static inline void wait_vblank(void) {
    while (!(*VGA_CTRL & CTRL_VBLANK));
}

static uint16_t lfsr = 0xACE1;
static inline uint16_t rand_u16(void) {
    uint16_t bit = ((lfsr >> 0) ^ (lfsr >> 2) ^ (lfsr >> 3) ^ (lfsr >> 5)) & 1;
    lfsr = (lfsr >> 1) | (bit << 15);
    return lfsr;
}

static const uint8_t row_colors[BRICK_ROWS] = {
    0b11000000, 0b11011000, 0b11110000, 0b00110000,
    0b00111100, 0b00000011, 0b11000011, 0b11111111
};

static const uint8_t trail_colors[TRAIL_LEN] = {
    0b11111111, 0b11111100, 0b11011000, 0b11000000, 0b01000000, 0b00100000
};

static uint8_t bricks[BRICK_ROWS][BRICK_COLS];
// Dirty tracker counter: 2 = erase on both buffers, 1 = erase on second buffer, 0 = clean
static uint8_t dirty_erase[BRICK_ROWS][BRICK_COLS]; 

static inline void clear_vga_buffer(volatile uint32_t *fb32) {
    for (int i = 0; i < (WIDTH * HEIGHT) / 4; i++) {
        fb32[i] = 0;
    }
}

static void init_board(void) {
    for (int r = 0; r < BRICK_ROWS; r++) {
        for (int c = 0; c < BRICK_COLS; c++) {
            bricks[r][c] = row_colors[r];
            dirty_erase[r][c] = 0;
        }
    }
    clear_vga_buffer(VGA_FB32);
    clear_vga_buffer(VGA_FB32 + (PAGE_SIZE / 4));
}

static inline void draw_rect_vga(volatile uint8_t *fb, int16_t rx, int16_t ry, int16_t rw, int16_t rh, uint8_t color) {
    if (rx < 0 || ry < 0 || rx + rw > WIDTH || ry + rh > HEIGHT) return;
    
    for (int16_t y = ry; y < ry + rh; y++) {
        volatile uint8_t *ptr = fb + (y * WIDTH + rx);
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

    init_board();

    // Game state
    int16_t ball_x = 160 << 4, ball_y = 120 << 4;
    int16_t ball_dx = 24, ball_dy = -32;
    const int16_t ball_size = 4;

    // Per-page trail state to prevent trail flickering across front/back buffers
    Pos2D page_trail[2][TRAIL_LEN];
    for (int p = 0; p < 2; p++) {
        for (int i = 0; i < TRAIL_LEN; i++) {
            page_trail[p][i].x = 160;
            page_trail[p][i].y = 120;
        }
    }
    uint8_t trail_head[2] = {0, 0};

    int16_t paddle_w = 40, paddle_h = 6;
    int16_t paddle_x = 140;
    int16_t old_paddle_x[2] = {140, 140};
    const int16_t paddle_y = 185;

    while (1) {
        uint8_t back_page = !active_page;
        uint32_t back_page_offset = (back_page == 1) ? PAGE_SIZE : 0x00000;
        volatile uint8_t *vga_back8 = VGA_FB8 + back_page_offset;

        // 1. Erase old trail & paddle for THIS specific buffer page
        uint8_t p_head = trail_head[back_page];
        uint8_t tail_idx = (p_head + 1) % TRAIL_LEN;
        draw_rect_vga(vga_back8, page_trail[back_page][tail_idx].x, page_trail[back_page][tail_idx].y, ball_size, ball_size, 0x00);

        if (old_paddle_x[back_page] != paddle_x) {
            draw_rect_vga(vga_back8, old_paddle_x[back_page], paddle_y, paddle_w, paddle_h, 0x00);
            old_paddle_x[back_page] = paddle_x;
        }

        // 2. Erase any dirty destroyed bricks on this buffer page
        for (int r = 0; r < BRICK_ROWS; r++) {
            for (int c = 0; c < BRICK_COLS; c++) {
                if (dirty_erase[r][c] > 0) {
                    draw_rect_vga(vga_back8, BRICK_LEFT + c * BRICK_W, BRICK_TOP + r * BRICK_H, BRICK_W - 2, BRICK_H - 2, 0x00);
                    dirty_erase[r][c]--; // Decrement so both pages get cleared once
                }
            }
        }

        // 3. AI Paddle Logic
        int16_t bx = ball_x >> 4;
        int16_t by = ball_y >> 4;
        int16_t target_paddle_x = bx - (paddle_w / 2);

        if (paddle_x < target_paddle_x) paddle_x += 3;
        else if (paddle_x > target_paddle_x) paddle_x -= 3;

        if (paddle_x < 0) paddle_x = 0;
        if (paddle_x > WIDTH - paddle_w) paddle_x = WIDTH - paddle_w;

        // 4. Move Ball & Collisions
        ball_x += ball_dx;
        ball_y += ball_dy;
        bx = ball_x >> 4;
        by = ball_y >> 4;

        if (bx <= 0) { ball_x = 0; ball_dx = -ball_dx; }
        else if (bx >= WIDTH - ball_size) { ball_x = (WIDTH - ball_size) << 4; ball_dx = -ball_dx; }

        if (by <= 0) { ball_y = 0; ball_dy = -ball_dy; }
        else if (by >= HEIGHT - ball_size) {
            ball_x = 160 << 4; ball_y = 100 << 4;
            ball_dx = (rand_u16() & 1) ? 24 : -24;
            ball_dy = -32;
            init_board();
        }

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
                    
                    bricks[r][c] = 0;
                    dirty_erase[r][c] = 2; // Flag to erase on BOTH frame buffers!
                    ball_dy = -ball_dy;
                    break;
                }
            }
        }

        if (active_bricks == 0) {
            init_board();
            ball_y = 100 << 4; ball_dy = 32;
        }

        // 5. Update Trail History for THIS back buffer page
        trail_head[back_page] = (p_head + 1) % TRAIL_LEN;
        page_trail[back_page][trail_head[back_page]].x = bx;
        page_trail[back_page][trail_head[back_page]].y = by;

        // 6. Draw Active Bricks
        for (int r = 0; r < BRICK_ROWS; r++) {
            for (int c = 0; c < BRICK_COLS; c++) {
                if (bricks[r][c] != 0) {
                    draw_rect_vga(vga_back8, BRICK_LEFT + c * BRICK_W, BRICK_TOP + r * BRICK_H, 
                                  BRICK_W - 2, BRICK_H - 2, bricks[r][c]);
                }
            }
        }

        // 7. Draw Ball Trail for THIS page
        for (int i = 0; i < TRAIL_LEN; i++) {
            uint8_t idx = (trail_head[back_page] + TRAIL_LEN - i) % TRAIL_LEN;
            draw_rect_vga(vga_back8, page_trail[back_page][idx].x, page_trail[back_page][idx].y, ball_size, ball_size, trail_colors[i]);
        }

        // 8. Draw Paddle
        draw_rect_vga(vga_back8, paddle_x, paddle_y, paddle_w, paddle_h, 0b11111111);

        // 9. Page Swap on VBLANK
        wait_vblank();
        active_page = !active_page;
        *VGA_CTRL = CTRL_MODE_GFX | (active_page ? CTRL_PAGE_1 : 0);
    }
}
