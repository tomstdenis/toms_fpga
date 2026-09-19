#include "lt1000.h"
#include "gfx.h"

// -----------------------------------------------------------------------------
// Global State & IRQ Callbacks
// -----------------------------------------------------------------------------

static volatile uint32_t frames = 0;
static volatile int vsync_enabled = 1;

static void fps_counter_handler(uint32_t data) {
    puts("\r\nFPS: "); 
    puts_dec(frames);
    if (vsync_enabled) {
        puts(" (VSYNC ON)");
    } else {
        puts(" (VSYNC OFF)");
    }
    frames = 0;
}

static void vsync_toggle_handler(uint32_t data) {
    vsync_enabled = !vsync_enabled;
}

static void uart_handler(uint32_t data) {
    if (UART_STATUS & UART_STATUS_RX_READY) {
        uint32_t v = UART_DATA;
        UART_DATA = v;
        if (v == 27) { // ESC key
            yield_cli();
            void (*bios_entry)(void) = (void (*)(void))ROM_ADDR;
            bios_entry();
            while (1);
        }
    }
}

// -----------------------------------------------------------------------------
// Fixed-Point Math & 3D Pyramid Model
// -----------------------------------------------------------------------------

TCM_FUNC static int fast_sin(int angle) {
    angle = angle & 255;
    if (angle < 64)  return (angle * 2);
    if (angle < 128) return ((128 - angle) * 2);
    if (angle < 192) return (-(angle - 128) * 2);
    return (-(256 - angle) * 2);
}

TCM_FUNC static int fast_cos(int angle) {
    return fast_sin(angle + 64);
}

// Scaled up by ~50% (Symmetrical around origin)
static const int pyramid_verts[5][3] = {
    {   0, -40,   0}, // 0: Apex (Top)
    {-40,  40, -40}, // 1: Front-Left
    { 40,  40, -40}, // 2: Front-Right
    { 40,  40,  40}, // 3: Back-Right
    {-40,  40,  40}  // 4: Back-Left
};

typedef struct {
    int v0, v1, v2;
    uint8_t color;
} Face;

// Using your RGB332 byte color values
static const Face pyramid_faces[6] = {
    {0, 1, 2, 0b11100000}, // Front Side (Red)
    {0, 2, 3, 0b00011100}, // Right Side (Green)
    {0, 3, 4, 0b00000011}, // Back Side  (Blue)
    {0, 4, 1, 0b11111100}, // Left Side  (Yellow)
    {1, 4, 3, 0b11100011}, // Base Tri 1 (Purple)
    {1, 3, 2, 0b11100011}  // Base Tri 2 (Purple)
};

TCM_FUNC static void draw_rotating_pyramid(int cx, int cy, int rx, int ry, int rz) {
    int transformed[5][3];
    int projected[5][2];

    int sin_x = fast_sin(rx), cos_x = fast_cos(rx);
    int sin_y = fast_sin(ry), cos_y = fast_cos(ry);
    int sin_z = fast_sin(rz), cos_z = fast_cos(rz);

    const int camera_dist = 180;

    // 1. Strict Sequential 3D Euler Transformation (Yaw -> Pitch -> Roll)
    for (int i = 0; i < 5; i++) {
        int x = pyramid_verts[i][0];
        int y = pyramid_verts[i][1];
        int z = pyramid_verts[i][2];

        // Yaw (Y-axis)
        int x1 = (x * cos_y - z * sin_y) >> 7;
        int y1 = y;
        int z1 = (x * sin_y + z * cos_y) >> 7;

        // Pitch (X-axis)
        int x2 = x1;
        int y2 = (y1 * cos_x - z1 * sin_x) >> 7;
        int z2 = (y1 * sin_x + z1 * cos_x) >> 7;

        // Roll (Z-axis)
        int x3 = (x2 * cos_z - y2 * sin_z) >> 7;
        int y3 = (x2 * sin_z + y2 * cos_z) >> 7;
        int z3 = z2;

        transformed[i][0] = x3;
        transformed[i][1] = y3;
        transformed[i][2] = z3;

        // Perspective Projection
        int z_offset = z3 + camera_dist;
        if (z_offset < 1) z_offset = 1;

        projected[i][0] = cx + ((x3 * 160) / z_offset);
        projected[i][1] = cy + ((y3 * 160) / z_offset);
    }

    // 2. Camera-Space Normal Culling & Rendering
    for (int i = 0; i < 6; i++) {
        int i0 = pyramid_faces[i].v0;
        int i1 = pyramid_faces[i].v1;
        int i2 = pyramid_faces[i].v2;

        // Edge vectors in 3D camera space
        int ax = transformed[i1][0] - transformed[i0][0];
        int ay = transformed[i1][1] - transformed[i0][1];
        int az = transformed[i1][2] - transformed[i0][2];

        int bx = transformed[i2][0] - transformed[i0][0];
        int by = transformed[i2][1] - transformed[i0][1];
        int bz = transformed[i2][2] - transformed[i0][2];

        // Face Normal (Cross Product: A x B)
        int nx = (ay * bz) - (az * by);
        int ny = (az * bx) - (ax * bz);
        int nz = (ax * by) - (ay * bx);

        // Vector from face vertex to Camera at (0, 0, -camera_dist)
        int vx = transformed[i0][0];
        int vy = transformed[i0][1];
        int vz = transformed[i0][2] + camera_dist;

        // Dot product with View Vector (Back-face test)
        int dot = (nx * vx) + (ny * vy) + (nz * vz);

        if (dot < 0) {
            int x0 = projected[i0][0], y0 = projected[i0][1];
            int x1 = projected[i1][0], y1 = projected[i1][1];
            int x2 = projected[i2][0], y2 = projected[i2][1];

            gfx_fill_triangle(x0, y0, x1, y1, x2, y2, pyramid_faces[i].color);
            gfx_triangle(x0, y0, x1, y1, x2, y2, 0b11111111); // White Wireframe
        }
    }
}

// -----------------------------------------------------------------------------
// Entry Point
// -----------------------------------------------------------------------------

int main(void) {
    gfx_set_mode(1);

    yield_init();
    yield_sei();

    yield_add_irq(YIELD_IRQ_TIMER, 1000000UL * yield_usec_to_cycles(), 0, fps_counter_handler);
    yield_add_irq(YIELD_IRQ_TIMER, 5000000UL * yield_usec_to_cycles(), 0, vsync_toggle_handler);
    yield_add_irq(YIELD_IRQ_UART_RX_READY, 0, 0, uart_handler);

    int frame = 0;

    while (1) {
        yield();

        gfx_clear(0x00);

        // Render pyramid at center screen with 3-axis rotation
        draw_rotating_pyramid(GFX_WIDTH / 2, GFX_HEIGHT / 2, frame * 2, frame * 3, frame * 1);

        // UI Overlay
        gfx_puts(8, 8, "LT1000 3D DEMO", 0b11111100, 0x00, 1);
        gfx_puts(8, 20, "VSYNC:", 0b11111111, 0x00, 1);
        if (vsync_enabled) {
            gfx_puts(56, 20, "ON  (5s TOGGLE)", 0b00011100, 0x00, 1);
        } else {
            gfx_puts(56, 20, "OFF (5s TOGGLE)", 0b11100000, 0x00, 1);
        }

        if (vsync_enabled) {
            gfx_vsync();
        }

        gfx_flip_page();

        frame++;
        frames++;
    }

    return 0;
}
