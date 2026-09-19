#include "lt1000.h"

#define SCREEN_WIDTH  320
#define SCREEN_HEIGHT 200
#define FB_SIZE       (SCREEN_WIDTH * SCREEN_HEIGHT)

#define NUM_BOIDS     32
#define FIXED_SHIFT   8   // 24.8 Fixed-point format

// Flocking parameters
#define VISUAL_RANGE  30
#define MIN_DISTANCE  10
#define SEPARATION_WT 5
#define ALIGNMENT_WT  4
#define COHESION_WT   3

#define MAX_SPEED     (4 << FIXED_SHIFT)
#define MIN_SPEED     (1 << FIXED_SHIFT)

// Spatial Grid Configuration (30x30 pixel cells matching VISUAL_RANGE)
#define GRID_CELL_SIZE VISUAL_RANGE
#define GRID_COLS      11 // (320 / 30) + 1
#define GRID_ROWS      7  // (200 / 30) + 1
#define MAX_CELL_BOIDS 32

typedef struct {
    uint8_t count;
    uint8_t indices[MAX_CELL_BOIDS];
} grid_cell_t;

static grid_cell_t grid[GRID_ROWS][GRID_COLS];

// Offset buffer past your code region in PSRAM
uint8_t *PSRAM_BACK_BUFFER;

typedef struct {
    int32_t x, y;     // 24.8 fixed point
    int32_t vx, vy;   // 24.8 fixed point
} boid_t;

static boid_t boids[NUM_BOIDS];

// Tracks previous frame positions for dirty-rectangle clearing
static int16_t prev_px[NUM_BOIDS];
static int16_t prev_py[NUM_BOIDS];

static uint32_t rng_state = 0xA5A55A5A;
static uint32_t rand_u32(void) {
    rng_state ^= rng_state << 13;
    rng_state ^= rng_state >> 17;
    rng_state ^= rng_state << 5;
    return rng_state;
}

static inline uint8_t rgb332(uint8_t r, uint8_t g, uint8_t b) {
    return ((r & 0x07) << 5) | ((g & 0x07) << 2) | (b & 0x03);
}

// Maps velocity direction and speed into full dynamic RGB332 palette
static uint8_t get_boid_color(int id, int32_t vx, int32_t vy) {
    int32_t speed_x = (vx > 0 ? vx : -vx) >> (FIXED_SHIFT - 3); // 0 to 8+
    int32_t speed_y = (vy > 0 ? vy : -vy) >> (FIXED_SHIFT - 3);

    uint8_t r = 0, g = 0, b = 0;

    r = (speed_x > 7) ? 7 : (uint8_t)speed_x;
    g = (speed_y > 7) ? 7 : (uint8_t)speed_y;

    uint8_t dir_flag = ((vx > 0) ? 1 : 0) | ((vy > 0) ? 2 : 0);
    b = (id + dir_flag) & 0x03;

    if (r == 0 && g == 0) {
        r = (id & 0x07);
        g = 7 - r;
    }

    return rgb332(r, g, b);
}

static void init_boids(void) {
    for (int i = 0; i < NUM_BOIDS; i++) {
        boids[i].x = (10 + (rand_u32() % (SCREEN_WIDTH - 20))) << FIXED_SHIFT;
        boids[i].y = (10 + (rand_u32() % (SCREEN_HEIGHT - 20))) << FIXED_SHIFT;
        
        int32_t vx = ((int32_t)(rand_u32() % 7) - 3);
        int32_t vy = ((int32_t)(rand_u32() % 7) - 3);
        boids[i].vx = (vx == 0 ? 1 : vx) << FIXED_SHIFT;
        boids[i].vy = (vy == 0 ? 1 : vy) << FIXED_SHIFT;

        // Initialize tracking positions to invalid off-screen markers
        prev_px[i] = -1;
        prev_py[i] = -1;
    }

    // Do a single full clear of PSRAM on boot
    memset(PSRAM_BACK_BUFFER, 0x00, FB_SIZE);
}

static void update_boids(void) {
    // 1. Clear spatial grid
    for (int r = 0; r < GRID_ROWS; r++) {
        for (int c = 0; c < GRID_COLS; c++) {
            grid[r][c].count = 0;
        }
    }

    // 2. Bin every boid into its 30x30 screen grid cell
    for (int i = 0; i < NUM_BOIDS; i++) {
        int gx = (boids[i].x >> FIXED_SHIFT) / GRID_CELL_SIZE;
        int gy = (boids[i].y >> FIXED_SHIFT) / GRID_CELL_SIZE;

        if (gx >= 0 && gx < GRID_COLS && gy >= 0 && gy < GRID_ROWS) {
            grid_cell_t *cell = &grid[gy][gx];
            if (cell->count < MAX_CELL_BOIDS) {
                cell->indices[cell->count++] = (uint8_t)i;
            }
        }
    }

    // 3. Process flocking math ONLY against boids in neighboring grid cells
    for (int i = 0; i < NUM_BOIDS; i++) {
        int32_t close_dx = 0, close_dy = 0;
        int32_t xpos_avg = 0, ypos_avg = 0;
        int32_t xvel_avg = 0, yvel_avg = 0;
        int neighbors = 0;

        int32_t ix = boids[i].x >> FIXED_SHIFT;
        int32_t iy = boids[i].y >> FIXED_SHIFT;

        int gx = ix / GRID_CELL_SIZE;
        int gy = iy / GRID_CELL_SIZE;

        // Check only the 3x3 block of surrounding grid cells
        for (int dry = -1; dry <= 1; dry++) {
            int target_gy = gy + dry;
            if (target_gy < 0 || target_gy >= GRID_ROWS) continue;

            for (int drx = -1; drx <= 1; drx++) {
                int target_gx = gx + drx;
                if (target_gx < 0 || target_gx >= GRID_COLS) continue;

                grid_cell_t *cell = &grid[target_gy][target_gx];

                for (int k = 0; k < cell->count; k++) {
                    int j = cell->indices[k];
                    if (i == j) continue;

                    int32_t jx = boids[j].x >> FIXED_SHIFT;
                    int32_t jy = boids[j].y >> FIXED_SHIFT;

                    int32_t dx = jx - ix;
                    int32_t dy = jy - iy;

                    // Quick box test before expensive distance math
                    if (dx >= -VISUAL_RANGE && dx <= VISUAL_RANGE &&
                        dy >= -VISUAL_RANGE && dy <= VISUAL_RANGE) {
                        
                        int32_t dist_sq = (dx * dx) + (dy * dy);
                        
                        if (dist_sq < (VISUAL_RANGE * VISUAL_RANGE)) {
                            if (dist_sq < (MIN_DISTANCE * MIN_DISTANCE)) {
                                close_dx -= dx;
                                close_dy -= dy;
                            }

                            xpos_avg += boids[j].x;
                            ypos_avg += boids[j].y;
                            xvel_avg += boids[j].vx;
                            yvel_avg += boids[j].vy;
                            neighbors++;
                        }
                    }
                }
            }
        }

        if (neighbors > 0) {
            xpos_avg /= neighbors;
            ypos_avg /= neighbors;
            xvel_avg /= neighbors;
            yvel_avg /= neighbors;

            boids[i].vx += ((xpos_avg - boids[i].x) * COHESION_WT) >> 7;
            boids[i].vy += ((ypos_avg - boids[i].y) * COHESION_WT) >> 7;

            boids[i].vx += ((xvel_avg - boids[i].vx) * ALIGNMENT_WT) >> 7;
            boids[i].vy += ((yvel_avg - boids[i].vy) * ALIGNMENT_WT) >> 7;
        }

        boids[i].vx += (close_dx << FIXED_SHIFT) * SEPARATION_WT >> 3;
        boids[i].vy += (close_dy << FIXED_SHIFT) * SEPARATION_WT >> 3;

        int32_t margin = 20;
        int32_t turn = 1 << (FIXED_SHIFT - 1);
        if (ix < margin) boids[i].vx += turn;
        if (ix > SCREEN_WIDTH - margin) boids[i].vx -= turn;
        if (iy < margin) boids[i].vy += turn;
        if (iy > SCREEN_HEIGHT - margin) boids[i].vy -= turn;

        int32_t speed_x = boids[i].vx > 0 ? boids[i].vx : -boids[i].vx;
        int32_t speed_y = boids[i].vy > 0 ? boids[i].vy : -boids[i].vy;
        int32_t approx_speed = speed_x + speed_y;

        if (approx_speed > MAX_SPEED) {
            boids[i].vx = (boids[i].vx * MAX_SPEED) / approx_speed;
            boids[i].vy = (boids[i].vy * MAX_SPEED) / approx_speed;
        } else if (approx_speed < MIN_SPEED && approx_speed > 0) {
            boids[i].vx = (boids[i].vx * MIN_SPEED) / approx_speed;
            boids[i].vy = (boids[i].vy * MIN_SPEED) / approx_speed;
        }

        boids[i].x += boids[i].vx;
        boids[i].y += boids[i].vy;

        if (boids[i].x < 0) boids[i].x = (SCREEN_WIDTH - 2) << FIXED_SHIFT;
        if (boids[i].x >= (SCREEN_WIDTH << FIXED_SHIFT)) boids[i].x = 2 << FIXED_SHIFT;
        if (boids[i].y < 0) boids[i].y = (SCREEN_HEIGHT - 2) << FIXED_SHIFT;
        if (boids[i].y >= (SCREEN_HEIGHT << FIXED_SHIFT)) boids[i].y = 2 << FIXED_SHIFT;
    }
}

// In-place spatial sort by Y-coordinate to keep memory accesses local
static void sort_boids_by_y(void) {
    for (int i = 1; i < NUM_BOIDS; i++) {
        boid_t temp = boids[i];
        int j = i - 1;
        while (j >= 0 && boids[j].y > temp.y) {
            boids[j + 1] = boids[j];
            j--;
        }
        boids[j + 1] = temp;
    }
}

static void render_to_psram(void) {
    uint8_t *psram_buf = PSRAM_BACK_BUFFER;

    // 1. Erase ONLY old boid pixels (640 bytes instead of 64,000 bytes memset)
    for (int i = 0; i < NUM_BOIDS; i++) {
        int16_t px = prev_px[i];
        int16_t py = prev_py[i];

        if (px >= 1 && px < SCREEN_WIDTH - 1 && py >= 1 && py < SCREEN_HEIGHT - 1) {
            int idx = py * SCREEN_WIDTH + px;
            psram_buf[idx]                = 0x00;
            psram_buf[idx - 1]            = 0x00;
            psram_buf[idx + 1]            = 0x00;
            psram_buf[idx - SCREEN_WIDTH] = 0x00;
            psram_buf[idx + SCREEN_WIDTH] = 0x00;
        }
    }

    // 2. Sort boids vertically so pixel writes move sequentially through cache lines
    sort_boids_by_y();

    // 3. Render boids at new positions and record coordinates
    for (int i = 0; i < NUM_BOIDS; i++) {
        int32_t px = boids[i].x >> FIXED_SHIFT;
        int32_t py = boids[i].y >> FIXED_SHIFT;

        prev_px[i] = (int16_t)px;
        prev_py[i] = (int16_t)py;

        if (px >= 1 && px < SCREEN_WIDTH - 1 && py >= 1 && py < SCREEN_HEIGHT - 1) {
            uint8_t color = get_boid_color(i, boids[i].vx, boids[i].vy);

            int idx = py * SCREEN_WIDTH + px;
            psram_buf[idx]                = color;
            psram_buf[idx - 1]            = color;
            psram_buf[idx + 1]            = color;
            psram_buf[idx - SCREEN_WIDTH] = color;
            psram_buf[idx + SCREEN_WIDTH] = color;
        }
    }
}

static void copy_psram_to_vga(void) {
    volatile uint32_t *vga = (volatile uint32_t *)VGA_ADDR;
    uint32_t *psram = (uint32_t *)PSRAM_BACK_BUFFER;

    size_t words = FB_SIZE / 4;
    for (size_t i = 0; i < words; i++) {
        vga[i] = psram[i];
    }
}

static uint32_t frames = 0;
static void fps_counter(uint32_t data)
{
	putstr("\r\nFPS: "); puts_dec(frames);
//	printf("FPS: %x\n", frames);
    frames = 0;
}

static void timer_250msec(uint32_t data)
{
    uint32_t d = GPIO_DATA;
    d = (d << 1) | (d >> 31);
    GPIO_DATA = d;
}   

static void uart_handler(uint32_t data)
{
	// UART echo and ESC check to return to BIOS
	if (UART_STATUS & UART_STATUS_RX_READY) {
		uint32_t v = UART_DATA;
		UART_DATA = v;
		if (v == 27) { 
			exit(0);
		}
	}
}	

static void vblank_handler(uint32_t data)
{
//	uint32_t t = TIMER;
	update_boids();
	render_to_psram();
	copy_psram_to_vga();
//	t = TIMER - t;
//    putstr("\r\nT: "); puts_dec(t);
	++frames;
}	

int main(void)
{
	// turn off output buffering
	setvbuf(stdout, NULL, _IONBF, 0);

	// allocate ram for PSRAM backbuffer
	PSRAM_BACK_BUFFER = malloc(64000);
	
	// set GFX mode
    VGA_CTRL = VGA_CTRL_GFX_MODE;

	// turn on one LED for a fun blinky too
    GPIO_DATA = ~1UL;
    GPIO_OE   = 0xFFFFFFFF;

	// init, enable, and add IRQs to drive demo
    yield_init();
    yield_sei();
    yield_add_irq(YIELD_IRQ_TIMER, 1000000UL * yield_usec_to_cycles(), 0, fps_counter);
    yield_add_irq(YIELD_IRQ_TIMER, 250UL * 1000UL * yield_usec_to_cycles(), 0, timer_250msec);
    yield_add_irq(YIELD_IRQ_UART_RX_READY, 0, 0, uart_handler);
    yield_add_irq(YIELD_IRQ_VBLANK, 0, 0, vblank_handler);

	// init sim
    init_boids();

	// drive yield loop
    while (1) {
		yield();
    }

    return 0;
}
