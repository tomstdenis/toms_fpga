/*
 * lt1000_3d_cube.c - Hardware-Accelerated 3D Rotating Cube Demo for LT1000 SoC
 *
 * Direct Hardware MMIO FPU Integration:
 *   - Fast inline helper functions targeting FPU_IN_A / FPU_IN_B / FPU_CTRL registers.
 *   - LUT-based Sine/Cosine routines in memory.
 *   - Double-buffered VGA rendering (320x200x8bpp).
 */

#include "lt1000.h"

// -----------------------------------------------------------------------------
// Low-Level Hardware FPU Helpers
// -----------------------------------------------------------------------------

static inline float fpu_add(float a, float b) {
    FPU_IN_A = a;
    FPU_IN_B = b;
    FPU_CTRL = FPU_CTRL_VALID | FPU_CTRL_OP_FADD;
    while (!(FPU_CTRL & FPU_CTRL_VALID));
    return FPU_OUT;
}

static inline float fpu_sub(float a, float b) {
    FPU_IN_A = a;
    FPU_IN_B = b;
    FPU_CTRL = FPU_CTRL_VALID | FPU_CTRL_OP_FSUB;
    while (!(FPU_CTRL & FPU_CTRL_VALID));
    return FPU_OUT;
}

static inline float fpu_mul(float a, float b) {
    FPU_IN_A = a;
    FPU_IN_B = b;
    FPU_CTRL = FPU_CTRL_VALID | FPU_CTRL_OP_FMUL;
    while (!(FPU_CTRL & FPU_CTRL_VALID));
    return FPU_OUT;
}

static inline float fpu_div(float a, float b) {
    FPU_IN_A = a;
    FPU_IN_B = b;
    FPU_CTRL = FPU_CTRL_VALID | FPU_CTRL_OP_FDIV;
    while (!(FPU_CTRL & FPU_CTRL_VALID));
    return FPU_OUT;
}

static inline uint32_t fpu_cmp(float a, float b) {
    FPU_IN_A = a;
    FPU_IN_B = b;
    FPU_CTRL = FPU_CTRL_VALID | FPU_CTRL_OP_FCMP;
    while (!(FPU_CTRL & FPU_CTRL_VALID));
    return FPU_OUT_RAW;
}

static inline int32_t fpu_fsti(float a) {
    FPU_IN_A = a;
    FPU_CTRL = FPU_CTRL_VALID | FPU_CTRL_OP_FSTI;
    while (!(FPU_CTRL & FPU_CTRL_VALID));
    return (int32_t)FPU_OUT_RAW;
}

static inline float fpu_fldi(int32_t a) {
	float *b = (float *)&a;
    FPU_IN_A = *b; // just copy raw data let the core do the conversion
    FPU_CTRL = FPU_CTRL_VALID | FPU_CTRL_OP_FLDI;
    while (!(FPU_CTRL & FPU_CTRL_VALID));
    return FPU_OUT;
}

static inline float fpu_sqrt(float a) {
    FPU_IN_A = a;
    FPU_CTRL = FPU_CTRL_VALID | FPU_CTRL_OP_FSQRT;
    while (!(FPU_CTRL & FPU_CTRL_VALID));
    return FPU_OUT;
}

// Enable Autofire for sequence multiplication
static inline void fpu_enable_autofire_mul(float fixed_a) {
    FPU_IN_A = fixed_a;
    FPU_CTRL = FPU_CTRL_OP_FMUL | FPU_CTRL_AUTO_FIRE;
}

static inline float fpu_autofire_mul(float b) {
    FPU_IN_B = b; // Writing B triggers execution automatically
    while (!(FPU_CTRL & FPU_CTRL_VALID));
    return FPU_OUT;
}

// -----------------------------------------------------------------------------
// Sine / Cosine Lookup Table (256-entry float table)
// -----------------------------------------------------------------------------

#define SIN_LUT_SIZE 256
static float sin_lut[SIN_LUT_SIZE];

// Slow Taylor series used ONLY during table startup initialization
static float fpu_sin_init(float x) {
    while (fpu_cmp(x, 3.14159265f) == FPU_GT)  x = fpu_sub(x, 6.28318530f);
    while (fpu_cmp(x, -3.14159265f) == FPU_LT) x = fpu_add(x, 6.28318530f);

    float x2 = fpu_mul(x, x);
    float x3 = fpu_mul(x, x2);
    float x5 = fpu_mul(x3, x2);
    float x7 = fpu_mul(x5, x2);

    float t1 = fpu_div(x3, 6.0f);
    float t2 = fpu_div(x5, 120.0f);
    float t3 = fpu_div(x7, 5040.0f);

    float res = fpu_sub(x, t1);
    res = fpu_add(res, t2);
    res = fpu_sub(res, t3);
    return res;
}

static void init_trig_lut(void) {
    for (int i = 0; i < SIN_LUT_SIZE; i++) {
        float angle = fpu_div(fpu_mul(i, 6.28318530f), (float)SIN_LUT_SIZE);
        sin_lut[i] = fpu_sin_init(angle);
    }
}

// Ultra-fast lookup routines
static inline float lut_sin(uint8_t angle_idx) {
    return sin_lut[angle_idx];
}

static inline float lut_cos(uint8_t angle_idx) {
    return sin_lut[(uint8_t)(angle_idx + 64)]; // sin(x + PI/2) == sin(idx + 64)
}

// -----------------------------------------------------------------------------
// 3D Geometry & Camera Data Structures
// -----------------------------------------------------------------------------

typedef struct { float x, y, z; } Vec3;
typedef struct { int x, y; } Point2D;

typedef struct {
    int v0, v1, v2;
    uint8_t color;
} Triangle;

// Cube Vertices
static const Vec3 cube_vertices[8] = {
    { -1.0f, -1.0f, -1.0f },
    {  1.0f, -1.0f, -1.0f },
    {  1.0f,  1.0f, -1.0f },
    { -1.0f,  1.0f, -1.0f },
    { -1.0f, -1.0f,  1.0f },
    {  1.0f, -1.0f,  1.0f },
    {  1.0f,  1.0f,  1.0f },
    { -1.0f,  1.0f,  1.0f }
};

// 12 Triangles forming 6 cube faces (2 per face)
static const Triangle cube_indices[12] = {
    // Front face (Red)
    { 4, 5, 6, 0x28 }, { 4, 6, 7, 0x28 },
    // Back face (Green)
    { 1, 0, 3, 0x1C }, { 1, 3, 2, 0x1C },
    // Top face (Blue)
    { 3, 7, 6, 0x03 }, { 3, 6, 2, 0x03 },
    // Bottom face (Yellow)
    { 4, 0, 1, 0x3C }, { 4, 1, 5, 0x3C },
    // Right face (Cyan)
    { 5, 1, 2, 0x1F }, { 5, 2, 6, 0x1F },
    // Left face (Magenta)
    { 0, 4, 7, 0x23 }, { 0, 7, 3, 0x23 }
};

// -----------------------------------------------------------------------------
// 3D Transformation Pipeline
// -----------------------------------------------------------------------------

TCM_FUNC(transform_and_project) static void transform_and_project(const Vec3 *in, Point2D *out, int count, uint8_t rot_x, uint8_t rot_y) {
    float sin_x = lut_sin(rot_x);
    float cos_x = lut_cos(rot_x);
    float sin_y = lut_sin(rot_y);
    float cos_y = lut_cos(rot_y);

    const float fov = 160.0f; // Focal length / scale factor
    const float distance = 3.5f; // Camera offset along Z axis

    for (int i = 0; i < count; i++) {
        // Yaw Rotation around Y axis
        float x1 = fpu_add(fpu_mul(in[i].x, cos_y), fpu_mul(in[i].z, sin_y));
        float y1 = in[i].y;
        float z1 = fpu_sub(fpu_mul(in[i].z, cos_y), fpu_mul(in[i].x, sin_y));

        // Pitch Rotation around X axis
        float x2 = x1;
        float y2 = fpu_sub(fpu_mul(y1, cos_x), fpu_mul(z1, sin_x));
        float z2 = fpu_add(fpu_mul(y1, sin_x), fpu_mul(z1, cos_x));

        // World Translation
        float z_final = fpu_add(z2, distance);

        // Perspective Divide using hardware FDIV
        float proj_factor = fpu_div(fov, z_final);

        // Screen coordinate projection
        float screen_x = fpu_add(fpu_mul(x2, proj_factor), 160.0f); // Center X = 160
        float screen_y = fpu_add(fpu_mul(y2, proj_factor), 100.0f); // Center Y = 100

        // Convert Float to Integer (FSTI)
        out[i].x = fpu_fsti(screen_x);
        out[i].y = fpu_fsti(screen_y);
    }
}

// -----------------------------------------------------------------------------
// Main Entry Point
// -----------------------------------------------------------------------------

static void uart_irq(uint32_t data) {
    putstr("Returning to BIOS from IRQ...\r\n");
    UART_DATA;
    exit(0);
}

uint32_t frames;

static void timer(uint32_t data) {
    printf("FPS: %d\n", frames);
    frames = 0;
}

TCM_FUNC(demo) void demo(void) {
    // 1. Initialize LUT & Interrupts
    init_trig_lut();
    frames = 0;
    
    yield_init();
    yield_sei();
    yield_add_irq(YIELD_IRQ_UART_RX_READY, 0, 0, uart_irq);
    yield_add_irq(YIELD_IRQ_TIMER, 1000000UL * yield_usec_to_cycles(), 0, timer);
    
    gfx_set_mode(VGA_CTRL_GFX_MODE);

    Point2D proj_verts[8];
    uint8_t angle_x = 0;
    uint8_t angle_y = 0;

    while (1) {
        // 2. Clear off-screen draw buffer
        gfx_clear(0x00); // Black background

        // 3. Hardware-accelerated transformation & projection using trig LUT
        transform_and_project(cube_vertices, proj_verts, 8, angle_x, angle_y);

        // 4. Rasterize Triangles
        for (int i = 0; i < 12; i++) {
            Triangle t = cube_indices[i];
            
            // Draw Wireframe Mesh
            gfx_triangle(
                proj_verts[t.v0].x, proj_verts[t.v0].y,
                proj_verts[t.v1].x, proj_verts[t.v1].y,
                proj_verts[t.v2].x, proj_verts[t.v2].y,
                t.color
            );
        }

        // 5. Page Flip & VSYNC
        ++frames;
//        gfx_vsync();
        gfx_flip_page();

        // 6. Advance Rotation Angles (Automatic uint8_t 0..255 wrap-around!)
        angle_x += 1;
        angle_y += 2;

        yield();
    }
}

int main(void) {
    demo();
    return 0;
}
