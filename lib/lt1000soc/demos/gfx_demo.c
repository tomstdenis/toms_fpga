#include "lt1000.h"

// Simple 16x16 color sprite with color 0 as transparent
static const uint8_t sprite_16x16[256] = {
    0,0,0,0,0,0,14,14,14,14,0,0,0,0,0,0,
    0,0,0,0,14,14,15,15,15,15,14,14,0,0,0,0,
    0,0,0,14,15,15,12,12,12,12,15,15,14,0,0,0,
    0,0,14,15,12,12,10,10,10,10,12,12,15,14,0,0,
    0,14,15,12,10,10,10,10,10,10,10,10,12,15,14,0,
    0,14,15,12,10,10,15,10,10,15,10,10,12,15,14,0,
    14,15,12,10,10,10,15,10,10,15,10,10,10,12,15,14,
    14,15,12,10,10,10,10,10,10,10,10,10,10,12,15,14,
    14,15,12,10,10,10,10,10,10,10,10,10,10,12,15,14,
    14,15,12,10,10,15,10,10,10,10,15,10,10,12,15,14,
    0,14,15,12,10,10,15,15,15,15,10,10,12,15,14,0,
    0,14,15,12,10,10,10,10,10,10,10,10,12,15,14,0,
    0,0,14,15,12,12,10,10,10,10,12,12,15,14,0,0,
    0,0,0,14,15,15,12,12,12,12,15,15,14,0,0,0,
    0,0,0,0,14,14,15,15,15,15,14,14,0,0,0,0,
    0,0,0,0,0,0,14,14,14,14,0,0,0,0,0,0,
};

// Return to ROM when any UART byte is received
TCM_FUNC static void check_uart_exit(void) {
    if (UART_STATUS & UART_STATUS_RX_READY) {
        (void)UART_DATA; // Clear byte
        yield_cli();
        
        void (*rom_entry)(void) = (void (*)(void))ROM_ADDR;
        rom_entry();
        while (1);
    }
}

// 3D Cube Vertices (Scaled by 64 for fixed-point math)
static const int cube_verts[8][3] = {
    {-35, -35, -35}, { 35, -35, -35}, { 35,  35, -35}, {-35,  35, -35},
    {-35, -35,  35}, { 35, -35,  35}, { 35,  35,  35}, {-35,  35,  35}
};

// 12 Edges connecting 8 vertices
static const int cube_edges[12][2] = {
    {0,1}, {1,2}, {2,3}, {3,0},
    {4,5}, {5,6}, {6,7}, {7,4},
    {0,4}, {1,5}, {2,6}, {3,7}
};

// Integer Sine approximation (input 0..255 maps to -128..127)
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

// Draw 3D Wireframe Cube with rotation
TCM_FUNC static void draw_rotating_cube(int cx, int cy, int angle_x, int angle_y, uint8_t color) {
    int projected[8][2];

    int sin_x = fast_sin(angle_x), cos_x = fast_cos(angle_x);
    int sin_y = fast_sin(angle_y), cos_y = fast_cos(angle_y);

    for (int i = 0; i < 8; i++) {
        int x = cube_verts[i][0];
        int y = cube_verts[i][1];
        int z = cube_verts[i][2];

        // Rotate Y
        int x1 = (x * cos_y - z * sin_y) >> 7;
        int z1 = (x * sin_y + z * cos_y) >> 7;

        // Rotate X
        int y2 = (y * cos_x - z1 * sin_x) >> 7;
        int z2 = (y * sin_x + z1 * cos_x) >> 7;

        // Perspective Projection
        int distance = 140;
        int z_offset = z2 + distance;
        if (z_offset < 1) z_offset = 1;

        projected[i][0] = cx + ((x1 * 160) / z_offset);
        projected[i][1] = cy + ((y2 * 160) / z_offset);
    }

    // Draw all 12 edges
    for (int i = 0; i < 12; i++) {
        int v0 = cube_edges[i][0];
        int v1 = cube_edges[i][1];
        gfx_line(projected[v0][0], projected[v0][1],
                 projected[v1][0], projected[v1][1], color);
    }
}

int main(void) {
    VGA_CTRL = VGA_CTRL_GFX_MODE;
    yield_init();
    yield_sei(); // Enable yield timer/soft IRQs

    int frame = 0;

    while (1) {
        check_uart_exit();

        // 1. Clear Backbuffer
        gfx_clear(0x00);

        // 2. Animated Tunnel/Rings (Background)
        for (int r = 10; r < 140; r += 14) {
            int dynamic_r = r + (frame % 14);
            uint8_t ring_col = 32 + ((dynamic_r / 4) % 32);
            gfx_circle(GFX_WIDTH / 2, GFX_HEIGHT / 2, dynamic_r, ring_col);
        }

        // 3. Horizontal Grid Horizon Lines
        for (int y = 130; y < GFX_HEIGHT; y += 10) {
            gfx_hline(0, y, GFX_WIDTH, 0x08);
        }

        // 4. Bouncing Spheres (Filled & Outline)
        int bounce_y1 = 100 + (fast_sin(frame * 3) / 3);
        int bounce_y2 = 100 + (fast_cos(frame * 4) / 3);
        
        gfx_fill_circle(60, bounce_y1, 18, 0x28); // Green filled
        gfx_circle(60, bounce_y1, 18, 0x2F);      // Bright outline

        gfx_fill_circle(260, bounce_y2, 22, 0x48); // Blue filled
        gfx_circle(260, bounce_y2, 22, 0x4F);      // Bright outline

        // 5. 3D Wireframe Spinning Cube (Center foreground)
        draw_rotating_cube(GFX_WIDTH / 2, GFX_HEIGHT / 2 - 10, frame * 2, frame * 3, 0x0E);

        // 6. Transparent BitBlt Sprites (orbiting around the screen)
        int sp_x1 = (GFX_WIDTH / 2 - 8) + ((fast_cos(frame * 2) * 100) >> 7);
        int sp_y1 = (GFX_HEIGHT / 2 - 8) + ((fast_sin(frame * 2) * 60) >> 7);
        gfx_bitblit_transparent(sp_x1, sp_y1, 16, 16, sprite_16x16, 16, 0x00);

        int sp_x2 = (GFX_WIDTH / 2 - 8) - ((fast_cos(frame * 2) * 100) >> 7);
        int sp_y2 = (GFX_HEIGHT / 2 - 8) - ((fast_sin(frame * 2) * 60) >> 7);
        gfx_bitblit_transparent(sp_x2, sp_y2, 16, 16, sprite_16x16, 16, 0x00);

        // 7. Page Flip & Frame Sync
        gfx_flip_page();
        
        frame++;

        // Yield processing and accurate hardware delay using your API
        delay_ms(16); // ~60 FPS Target
    }

    return 0;
}
