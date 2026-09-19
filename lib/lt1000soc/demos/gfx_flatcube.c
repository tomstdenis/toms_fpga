#include "lt1000.h"

// With this set we render to PSRAM first and then copy to the VGA back buffer
// this is meant to stress test the cache a bunch
#define PSRAM_STRESS

#ifdef PSRAM_STRESS
#define CODE_SEC 
#else
#define CODE_SEC TCM_FUNC
#endif

#define VGA_FB32            ((volatile uint32_t *)VGA_ADDR)
#define PSRAM_BASE8         ((volatile uint8_t  *)(PSRAM_ADDR + 0x20000))
#define PSRAM_BASE32        ((volatile uint32_t *)(PSRAM_ADDR + 0x20000))
#define WIDTH               320
#define HEIGHT              200
#define PAGE_SIZE           0x10000 

static uint32_t frames = 0;
CODE_SEC static void fps_counter(uint32_t data)
{
	putstr("FPS: "); puts_dec(frames); putstr(", TCM_FREE == 0x"); puts_hex(TCM_FREE, 4); putstr("\r\n");
	frames = 0;
}

CODE_SEC static void timer_250msec(uint32_t data)
{
	uint32_t d = GPIO_DATA;
	d = (d << 1) | (d >> 31);
	GPIO_DATA = d;
}	

CODE_SEC static void wait_vblank(void) {
    while (!(VGA_CTRL & VGA_CTRL_VBLANK)) {
		yield();
	}
}

// Q8 Fixed-point sine/cosine
CODE_SEC static int16_t sin_q8(uint8_t angle) {
    static const uint8_t sin_table[65] = {
          0,   3,   6,   9,  12,  15,  18,  21,  24,  27,  30,  33,  36,  39,  42,  45,
         48,  51,  54,  57,  60,  63,  65,  68,  71,  73,  76,  78,  81,  83,  85,  88,
         90,  92,  94,  96,  98, 100, 102, 104, 106, 107, 109, 111, 112, 113, 115, 116,
        117, 118, 119, 120, 121, 122, 123, 124, 124, 125, 125, 126, 126, 126, 126, 126, 127
    };
    uint8_t idx = angle & 0x3F;
    if ((angle & 0x40) != 0) idx = 64 - idx;
    int16_t val = (int16_t)sin_table[idx] << 1;
    return ((angle & 0x80) != 0) ? -val : val;
}

CODE_SEC static int16_t cos_q8(uint8_t angle) {
    return sin_q8(angle + 64);
}

typedef struct { int16_t x, y, z; } Point3D;
typedef struct { int16_t x, y; } Point2D;

// Cube Vertices
static const Point3D cube_vertices[8] = {
    {-50, -50, -50}, { 50, -50, -50}, { 50,  50, -50}, {-50,  50, -50},
    {-50, -50,  50}, { 50, -50,  50}, { 50,  50,  50}, {-50,  50,  50}
};

// 6 Faces (Quad indices defined counter-clockwise for backface culling)
static const uint8_t cube_faces[6][4] = {
    {0, 3, 2, 1}, // Front
    {4, 5, 6, 7}, // Back
    {0, 1, 5, 4}, // Bottom
    {2, 3, 7, 6}, // Top
    {0, 4, 7, 3}, // Left
    {1, 2, 6, 5}  // Right
};

// Solid colors tuned for a 64-color / 2-bit per channel display palette
static const uint8_t face_colors[6] = {
    0b11000000, // Solid Red
    0b00110000, // Solid Green
    0b00000011, // Solid Blue
    0b11110000, // Yellow / Amber
    0b11000011, // Magenta
    0b00110011  // Cyan
};

	
// Scanline edge filling with 32-bit DWORD packing
CODE_SEC static void draw_span(volatile uint8_t *canvas, int16_t y, int16_t x1, int16_t x2, uint8_t color) {
    if (y < 0 || y >= HEIGHT) return;
    if (x1 > x2) { int16_t t = x1; x1 = x2; x2 = t; }
    if (x1 < 0) x1 = 0;
    if (x2 >= WIDTH) x2 = WIDTH - 1;

    int16_t count = x2 - x1 + 1;
    if (count <= 0) return;

    volatile uint8_t *ptr = canvas + (y * WIDTH + x1);

    // 1. Pad start with byte writes until 32-bit aligned
    while (((uintptr_t)ptr & 3) && count > 0) {
        *ptr++ = color;
        count--;
    }

    // 2. Main interior fill: 32-bit DWORD writes (4 pixels per store)
    if (count >= 4) {
        uint32_t color32 = (uint32_t)color | ((uint32_t)color << 8) |
                           ((uint32_t)color << 16) | ((uint32_t)color << 24);
        volatile uint32_t *ptr32 = (volatile uint32_t *)ptr;
        
        int16_t dwords = count >> 2; // count / 4
        while (dwords--) {
            *ptr32++ = color32;
        }

        ptr = (volatile uint8_t *)ptr32;
        count &= 3; // Remaining bytes (count % 4)
    }

    // 3. Pad remaining trailing bytes
    while (count > 0) {
        *ptr++ = color;
        count--;
    }
}

CODE_SEC static void fill_quad(volatile uint8_t *canvas, Point2D p[4], uint8_t color) {
    int16_t min_y = p[0].y, max_y = p[0].y;
    for (int i = 1; i < 4; i++) {
        if (p[i].y < min_y) min_y = p[i].y;
        if (p[i].y > max_y) max_y = p[i].y;
    }

    if (min_y < 0) min_y = 0;
    if (max_y >= HEIGHT) max_y = HEIGHT - 1;

    for (int16_t y = min_y; y <= max_y; y++) {
        int16_t min_x = 32767, max_x = -32768;

        for (int i = 0; i < 4; i++) {
            Point2D p1 = p[i];
            Point2D p2 = p[(i + 1) % 4];

            if ((p1.y <= y && p2.y > y) || (p2.y <= y && p1.y > y)) {
                int32_t dy = p2.y - p1.y;
                int32_t dx = p2.x - p1.x;
                int32_t num = (int32_t)(y - p1.y) * dx;
                
                // Fixed-point rounding division
                int32_t x_intersect = p1.x + ((num >= 0) ? ((num + (dy >> 1)) / dy) 
                                                         : ((num - (dy >> 1)) / dy));

                if (x_intersect < min_x) min_x = x_intersect;
                if (x_intersect > max_x) max_x = x_intersect;
            }
        }

        if (min_x <= max_x) {
            draw_span(canvas, y, min_x, max_x, color);
        }
    }
}

CODE_SEC void demo(void) {
	uint8_t active_page = 0;
	
    uint8_t rx = 0, ry = 0, rz = 0;
    volatile uint8_t  *psram_canvas   = PSRAM_BASE8;
    volatile uint32_t *psram_canvas32 = PSRAM_BASE32;
    
    GPIO_DATA = ~1UL;
    GPIO_OE   = 0xFFFFFFFF;

	yield_init();
	yield_sei();
	yield_add_irq(YIELD_IRQ_TIMER, 1000000UL * yield_usec_to_cycles(), 0, fps_counter);
	yield_add_irq(YIELD_IRQ_TIMER, 250UL * 1000UL * yield_usec_to_cycles(), 0, timer_250msec);
	
	VGA_CTRL = VGA_CTRL_GFX_MODE | (active_page ? VGA_CTRL_PAGE_SEL : 0);

    while (1) {
        uint32_t back_page_offset = (active_page == 0) ? PAGE_SIZE : 0x00000;
        volatile uint32_t *vga_back_buffer32 = VGA_FB32 + (back_page_offset / 4);
        
        yield();

        // 1. Clear PSRAM Background to dark gray/black
        for (int i = 0; i < (WIDTH * HEIGHT) / 4; i++) {
#ifdef PSRAM_STRESS        
            psram_canvas32[i] = 0x00000000;
#else
            vga_back_buffer32[i] = 0x00000000;
#endif
        }

        // Trig setup
        int16_t cx = cos_q8(rx), sx = sin_q8(rx);
        int16_t cy = cos_q8(ry), sy = sin_q8(ry);
        int16_t cz = cos_q8(rz), sz = sin_q8(rz);

        Point2D proj[8];

        // 2. Rotate & Project Vertices
        for (int i = 0; i < 8; i++) {
            int32_t x = cube_vertices[i].x;
            int32_t y = cube_vertices[i].y;
            int32_t z = cube_vertices[i].z;

            int32_t y1 = (y * cx - z * sx) >> 8;
            int32_t z1 = (y * sx + z * cx) >> 8;
            int32_t x2 = (x * cy + z1 * sy) >> 8;
            int32_t z2 = (-x * sy + z1 * cy) >> 8;
            int32_t x3 = (x2 * cz - y1 * sz) >> 8;
            int32_t y3 = (x2 * sz + y1 * cz) >> 8;

            int32_t dist = 180 + z2;
            proj[i].x = 160 + ((x3 * 160) / dist);
            proj[i].y = 100 + ((y3 * 160) / dist);
        }

        // 3. Backface Cull & Render Solid Quads
        for (int f = 0; f < 6; f++) {
            Point2D quad[4] = {
                proj[cube_faces[f][0]],
                proj[cube_faces[f][1]],
                proj[cube_faces[f][2]],
                proj[cube_faces[f][3]]
            };

            // 2D Cross Product check for winding order (determines if face points toward screen)
            int32_t cross_prod = (int32_t)(quad[1].x - quad[0].x) * (quad[2].y - quad[0].y) -
                                 (int32_t)(quad[1].y - quad[0].y) * (quad[2].x - quad[0].x);

            if (cross_prod < -16) { // Visible front-facing polygon!
#ifdef PSRAM_STRESS        
                fill_quad(psram_canvas, quad, face_colors[f]);
#else
                fill_quad((uint8_t *)vga_back_buffer32, quad, face_colors[f]);
#endif
            }
        }

        // 4. Blit PSRAM -> VGA Back Buffer
#ifdef PSRAM_STRESS        
        for (int i = 0; i < (WIDTH * HEIGHT) / 4; i++) {
            vga_back_buffer32[i] = psram_canvas32[i];
        }
#endif
        // 5. Swap Pages
        wait_vblank();
        ++frames;
        active_page = !active_page;
        VGA_CTRL = VGA_CTRL_GFX_MODE | (active_page ? VGA_CTRL_PAGE_SEL : 0);

        rx += 2;
        ry += 3;
        rz += 1;

        // uart echo
        if (UART_STATUS & UART_STATUS_RX_READY) {
			uint32_t v = UART_DATA;
			UART_DATA = v;
			if (v == 27) { 
				void (*bios_entry)(void) = (void (*)(void))0x01000000;
				bios_entry();
			}
		}
    }
}

void main(void) { demo(); }
