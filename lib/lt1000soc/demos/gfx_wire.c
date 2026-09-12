#include <stdint.h>

#define UART_DATA           ((volatile uint32_t *)0x10000018)
#define UART_STATUS         ((volatile uint32_t *)0x1000001C)
#define UART_STATUS_TX_FULL  1
#define UART_STATUS_TX_EMPTY 2
#define UART_STATUS_RX_READY 4

#define VGA_FB              ((volatile uint8_t  *)0x04000000)
#define VGA_FB32            ((volatile uint32_t *)0x04000000)
#define VGA_CTRL            ((volatile uint32_t *)0x10000020)

// PSRAM (nanosram + 8KB nanocache mapped at 0x08000000, 64KB offset)
#define PSRAM_BASE8         ((volatile uint8_t  *)0x08010000)
#define PSRAM_BASE32        ((volatile uint32_t *)0x08010000)

#define WIDTH               320
#define HEIGHT              200
#define PAGE_SIZE           0x10000 

#define MODE_TEXT           0
#define MODE_GFX            1

#define CTRL_MODE_GFX       (1 << 0)
#define CTRL_PAGE_1         (1 << 1)
#define CTRL_HBLANK         (1 << 2)
#define CTRL_VBLANK         (1 << 3)

static inline void delay_short(volatile uint32_t count) {
    while (count--) {
        __asm__ volatile ("nop");
    }
}

static void wait_vblank(void) {
    while (!(*VGA_CTRL & CTRL_VBLANK));
}

// Fixed-point sine (0..127 range mapped to Q8 representation)
static int16_t sin_q8(uint8_t angle) {
    static const uint8_t sin_table[65] = {
          0,   3,   6,   9,  12,  15,  18,  21,  24,  27,  30,  33,  36,  39,  42,  45,
         48,  51,  54,  57,  60,  63,  65,  68,  71,  73,  76,  78,  81,  83,  85,  88,
         90,  92,  94,  96,  98, 100, 102, 104, 106, 107, 109, 111, 112, 113, 115, 116,
        117, 118, 119, 120, 121, 122, 123, 124, 124, 125, 125, 126, 126, 126, 126, 126, 127
    };
    uint8_t idx = angle & 0x3F;
    if ((angle & 0x40) != 0) idx = 64 - idx;
    int16_t val = (int16_t)sin_table[idx] << 1; // Scale to ~256 (Q8 format)
    return ((angle & 0x80) != 0) ? -val : val;
}

static inline int16_t cos_q8(uint8_t angle) {
    return sin_q8(angle + 64);
}

// 3D Point Structure
typedef struct {
    int16_t x, y, z;
} Point3D;

typedef struct {
    int16_t x, y;
} Point2D;

// Cube Vertices (-60 to +60 model space units)
static const Point3D cube_vertices[8] = {
    {-60, -60, -60},
    { 60, -60, -60},
    { 60,  60, -60},
    {-60,  60, -60},
    {-60, -60,  60},
    { 60, -60,  60},
    { 60,  60,  60},
    {-60,  60,  60}
};

// 12 Edges connecting the 8 vertices
static const uint8_t cube_edges[12][2] = {
    {0, 1}, {1, 2}, {2, 3}, {3, 0}, // Front face
    {4, 5}, {5, 6}, {6, 7}, {7, 4}, // Back face
    {0, 4}, {1, 5}, {2, 6}, {3, 7}  // Connecting edges
};

// Bresenham's Line Algorithm directly targeting PSRAM canvas
static void draw_line_psram(volatile uint8_t *canvas, int16_t x0, int16_t y0, int16_t x1, int16_t y1, uint8_t color) {
    int16_t dx = (x1 > x0) ? (x1 - x0) : (x0 - x1);
    int16_t dy = (y1 > y0) ? (y1 - y0) : (y0 - y1);
    int16_t sx = (x0 < x1) ? 1 : -1;
    int16_t sy = (y0 < y1) ? 1 : -1;
    int16_t err = dx - dy;

    while (1) {
        if (x0 >= 0 && x0 < WIDTH && y0 >= 0 && y0 < HEIGHT) {
            canvas[y0 * WIDTH + x0] = color;
        }
        if (x0 == x1 && y0 == y1) break;
        int16_t e2 = 2 * err;
        if (e2 > -dy) {
            err -= dy;
            x0 += sx;
        }
        if (e2 < dx) {
            err += dx;
            y0 += sy;
        }
    }
}

void main(void)
{
    uint8_t active_page = 0;
    *VGA_CTRL = CTRL_MODE_GFX | (active_page ? CTRL_PAGE_1 : 0);

    uint8_t rx = 0, ry = 0, rz = 0;

    volatile uint8_t  *psram_canvas   = PSRAM_BASE8;
    volatile uint32_t *psram_canvas32 = PSRAM_BASE32;

    while (1) {
        uint32_t back_page_offset = (active_page == 0) ? PAGE_SIZE : 0x00000;
        volatile uint32_t *vga_back_buffer32 = VGA_FB32 + (back_page_offset / 4);

        // 1. Clear PSRAM Canvas (Unrolled 32-bit writes to stress-test dirty line evictions)
        for (int i = 0; i < (WIDTH * HEIGHT) / 4; i++) {
            psram_canvas32[i] = 0x00000000;
        }

        // Precalculate Trigonometry (Q8 fixed-point)
        int16_t cx = cos_q8(rx), sx = sin_q8(rx);
        int16_t cy = cos_q8(ry), sy = sin_q8(ry);
        int16_t cz = cos_q8(rz), sz = sin_q8(rz);

        Point2D projected[8];

        // 2. Rotate and Project Vertices
        for (int i = 0; i < 8; i++) {
            int32_t x = cube_vertices[i].x;
            int32_t y = cube_vertices[i].y;
            int32_t z = cube_vertices[i].z;

            // Pitch (X-axis)
            int32_t y1 = (y * cx - z * sx) >> 8;
            int32_t z1 = (y * sx + z * cx) >> 8;

            // Yaw (Y-axis)
            int32_t x2 = (x * cy + z1 * sy) >> 8;
            int32_t z2 = (-x * sy + z1 * cy) >> 8;

            // Roll (Z-axis)
            int32_t x3 = (x2 * cz - y1 * sz) >> 8;
            int32_t y3 = (x2 * sz + y1 * cz) >> 8;

            // Perspective projection (Z-distance offset = 200)
            int32_t distance = 200 + z2;
            projected[i].x = 160 + ((x3 * 160) / distance);
            projected[i].y = 100 + ((y3 * 160) / distance);
        }

        // 3. Draw Wireframe Edges into PSRAM
        for (int i = 0; i < 12; i++) {
            uint8_t p1 = cube_edges[i][0];
            uint8_t p2 = cube_edges[i][1];
            
            // Bright white/cyan RGB332 wireframe color
            draw_line_psram(psram_canvas, projected[p1].x, projected[p1].y, 
                                          projected[p2].x, projected[p2].y, 0x1F);
        }

        // 4. Blit PSRAM -> VGA Back Buffer
        for (int i = 0; i < (WIDTH * HEIGHT) / 4; i++) {
            vga_back_buffer32[i] = psram_canvas32[i];
        }

        // 5. Swap Pages & Sync
        wait_vblank();
        active_page = !active_page;
        *VGA_CTRL = CTRL_MODE_GFX | (active_page ? CTRL_PAGE_1 : 0);

        rx += 2;
        ry += 3;
        rz += 1;

        // UART Echo loop back check
        if (*UART_STATUS & UART_STATUS_RX_READY) {
            *UART_DATA = *UART_DATA;
        }
    }
}
