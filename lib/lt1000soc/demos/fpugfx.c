/*
 * lt1000_fractal.c - NanoFPU Hardware-Accelerated Fractal Demo for LT1000 SoC
 */

#include "lt1000.h"

// -----------------------------------------------------------------------------
// Helper Macro Wrappers for NanoFPU Comparisons
// -----------------------------------------------------------------------------

// Checks if a > b using fsub
static inline int fgt(float a, float b) {
    return (fcmp(fsub(a, b), 0.0f) == FPU_GT);
}

// Absolute value using bitwise mask or NanoFPU
static inline float fabs_fpu(float a) {
    return (fgt(a, 0.0f)) ? a : fsub(0.0f, a);
}

// -----------------------------------------------------------------------------
// "Real-Time" Animated Julia Set
// -----------------------------------------------------------------------------
#define MAX_ITER 16

TCM_FUNC(render_julia)
static void render_julia(float c_re, float c_im, float zoom, float time) {
    uint8_t *fb = gfx_get_draw_buffer();

    // 1. Precalculate initial coordinates and deltas (Only 2 divides per frame)
    float range_x = fmul(zoom, 2.0f);
    float range_y = fmul(zoom, 2.0f);
    
    float step_x  = fdiv(range_x, 320.0f); 
    float step_y  = fdiv(range_y, 200.0f);

    float start_x = fsub(0.0f, zoom);
    float start_y = fsub(0.0f, zoom);

    float z_im = start_y;

    // 2. Render top half only (y = 0 to 99) and mirror to bottom half
    for (int y = 0; y < (GFX_HEIGHT / 2); y++) {
        float z_re_row = start_x;
        
        // Target row pointers: top row (y) and origin-symmetric bottom row (199 - y)
        uint8_t *row_top = fb + (y * GFX_WIDTH);
        uint8_t *row_bot = fb + ((GFX_HEIGHT - 1 - y) * GFX_WIDTH);

        for (int x = 0; x < GFX_WIDTH; x++) {
            float cur_re = z_re_row;
            float cur_im = z_im;
            z_re_row = fadd(z_re_row, step_x);

            int iter = 0;

            // Inner Julia escape loop (16 iterations max)
            while (iter < MAX_ITER) {
                float re2 = fmul(cur_re, cur_re);
                float im2 = fmul(cur_im, cur_im);

                // Escape check using native NanoFPU hardware fcmp
                if (fcmp(fadd(re2, im2), 4.0f) == FPU_GT) break;

                // 2 * cur_re * cur_im via (re_im + re_im)
                float re_im = fmul(cur_re, cur_im);
                float next_im = fadd(fadd(re_im, re_im), c_im);

                // cur_re_next = re2 - im2 + c_re
                float next_re = fadd(fsub(re2, im2), c_re);

                cur_re = next_re;
                cur_im = next_im;
                iter++;
            }

            // Palette Mapping
			// Dynamic RGB332 color ramp based on iteration count
			uint8_t color;
			if (iter == MAX_ITER) {
				color = 0x00; // Interior remains deep black
			} else {
				// Cycle through palette using iteration index
				uint8_t idx = (iter + fsti(fmul(time, 10.0f))) & 0x0F; // + time for animated palette rotation!
				
				// Map iteration to RGB332 channels (3-bit Red, 3-bit Green, 2-bit Blue)
				uint8_t r = (idx & 0x07) << 5;          // Red ramps 0..7 -> bits [7:5]
				uint8_t g = ((idx >> 1) & 0x07) << 2;   // Green ramps -> bits [4:2]
				uint8_t b = (idx >> 2) & 0x03;          // Blue ramps 0..3 -> bits [1:0]
				
				color = r | g | b;
			}
            // Write top pixel
            row_top[x] = color;
            // Mirror to 180-degree symmetric bottom pixel: (319 - x, 199 - y)
            row_bot[GFX_WIDTH - 1 - x] = color;
        }

        z_im = fadd(z_im, step_y);
    }
}

// -----------------------------------------------------------------------------
// Main Entry Point & Animation Loop
// -----------------------------------------------------------------------------

static void uart_irq(uint32_t data) {
    putstr("Returning to BIOS from IRQ...\r\n");
    UART_DATA;
    exit(0);
}

uint32_t frames;

static void timer(uint32_t data) {
    printf("Fractal FPS: %d\n", frames);
    frames = 0;
}

void demo(void) {
    frames = 0;

    yield_init();
    yield_sei();
    yield_add_irq(YIELD_IRQ_UART_RX_READY, 0, 0, uart_irq);
    yield_add_irq(YIELD_IRQ_TIMER, 1000000UL * yield_usec_to_cycles(), 0, timer);

    gfx_set_mode(VGA_CTRL_GFX_MODE);

    // Initial Julia constant C = -0.7 + 0.27015i
    float c_re = -0.70f;
    float c_im = 0.27015f;

    // Animation state
    float time = 0.0f;
    float time_step = 0.0075f;
    
    volatile uint32_t render_cycles;
	uint32_t fno = 0;
	
    while (1) {
        // Morph the Julia Constant over time using NanoFPU math
        time = (fno & 0x20) ? fsub(time, time_step) : fadd(time, time_step);
        ++fno;
        
        // c_re = -0.7 + 0.1 * sin(time)
        // c_im = 0.27 + 0.1 * cos(time)
        // (Simulated sin/cos modulation via simple FPU wave math)
        float wave_re = fmul(0.08f, fsub(time, fldi(fsti(time)))); // Fractional morph
        float current_c_re = fadd(c_re, wave_re);

        render_cycles = TIMER;
        // Render fractal with a fixed view zoom factor (1.2f)
        render_julia(current_c_re, fadd(time, c_im), 1.2f, time);
        render_cycles = TIMER - render_cycles;

        ++frames;
//        if (!(frames & 31)) {
            printf("Julia Render Cycles: %lu\n", render_cycles);
//        }

        gfx_vsync();
        gfx_flip_page();

        yield();
    }
}

int main(void) {
    demo();
    return 0;
}
