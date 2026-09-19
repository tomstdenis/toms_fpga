#include "lt1000.h"

// Helper to get active off-screen buffer
TCM_FUNC uint8_t *gfx_get_draw_buffer(void) {
    // VGA_CTRL_PAGE_SEL (bit 1) tells us which page is currently displayed.
    // If bit 1 is set (Page 1 visible), we draw to Page 0 (VGA_ADDR).
    // If bit 1 is clear (Page 0 visible), we draw to Page 1 (VGA_ADDR + 64KB).
    if (VGA_CTRL & VGA_CTRL_PAGE_SEL) {
        return (uint8_t *)VGA_ADDR;
    } else {
        return (uint8_t *)(VGA_ADDR + GFX_PAGE_SIZE);
    }
}

// Flip visible page to display what was just drawn
TCM_FUNC uint8_t *gfx_flip_page(void) {
    VGA_CTRL ^= VGA_CTRL_PAGE_SEL;
    return gfx_get_draw_buffer();
}

// Fast clear using memset
TCM_FUNC void gfx_clear(uint8_t color) {
    memset(gfx_get_draw_buffer(), color, GFX_WIDTH * GFX_HEIGHT);
}

// Single pixel plot with bounds checking
TCM_FUNC void gfx_putpixel(int x, int y, uint8_t color) {
    if ((unsigned int)x >= GFX_WIDTH || (unsigned int)y >= GFX_HEIGHT) return;
    uint8_t *buf = gfx_get_draw_buffer();
    buf[y * GFX_WIDTH + x] = color;
}

// Fast horizontal line
TCM_FUNC void gfx_hline(int x, int y, int w, uint8_t color) {
    if (y < 0 || y >= GFX_HEIGHT || w <= 0) return;
    if (x < 0) { w += x; x = 0; }
    if (x + w > GFX_WIDTH) { w = GFX_WIDTH - x; }
    if (w <= 0) return;

    uint8_t *dest = gfx_get_draw_buffer() + (y * GFX_WIDTH) + x;
    memset(dest, color, w);
}

// Fast vertical line
TCM_FUNC void gfx_vline(int x, int y, int h, uint8_t color) {
    if (x < 0 || x >= GFX_WIDTH || h <= 0) return;
    if (y < 0) { h += y; y = 0; }
    if (y + h > GFX_HEIGHT) { h = GFX_HEIGHT - y; }
    if (h <= 0) return;

    uint8_t *dest = gfx_get_draw_buffer() + (y * GFX_WIDTH) + x;
    while (h--) {
        *dest = color;
        dest += GFX_WIDTH;
    }
}

// Bresenham's Line Algorithm
TCM_FUNC void gfx_line(int x0, int y0, int x1, int y1, uint8_t color) {
    int dx = x1 > x0 ? x1 - x0 : x0 - x1;
    int sx = x0 < x1 ? 1 : -1;
    int dy = y1 > y0 ? y0 - y1 : y1 - y0; // negative dy
    int sy = y0 < y1 ? 1 : -1;
    int err = dx + dy;

    while (1) {
        gfx_putpixel(x0, y0, color);
        if (x0 == x1 && y0 == y1) break;
        int e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
    }
}

// Rectangle outline
TCM_FUNC void gfx_rect(int x, int y, int w, int h, uint8_t color) {
    if (w <= 0 || h <= 0) return;
    gfx_hline(x, y, w, color);
    gfx_hline(x, y + h - 1, w, color);
    gfx_vline(x, y, h, color);
    gfx_vline(x + w - 1, y, h, color);
}

// Filled rectangle
TCM_FUNC void gfx_fill_rect(int x, int y, int w, int h, uint8_t color) {
    for (int i = 0; i < h; i++) {
        gfx_hline(x, y + i, w, color);
    }
}

// Midpoint Circle Algorithm (Outline)
TCM_FUNC void gfx_circle(int cx, int cy, int radius, uint8_t color) {
    int x = radius;
    int y = 0;
    int err = 0;

    while (x >= y) {
        gfx_putpixel(cx + x, cy + y, color);
        gfx_putpixel(cx + y, cy + x, color);
        gfx_putpixel(cx - y, cy + x, color);
        gfx_putpixel(cx - x, cy + y, color);
        gfx_putpixel(cx - x, cy - y, color);
        gfx_putpixel(cx - y, cy - x, color);
        gfx_putpixel(cx + y, cy - x, color);
        gfx_putpixel(cx + x, cy - y, color);

        if (err <= 0) {
            y += 1;
            err += 2 * y + 1;
        }
        if (err > 0) {
            x -= 1;
            err -= 2 * x + 1;
        }
    }
}

// Midpoint Circle Algorithm (Filled)
TCM_FUNC void gfx_fill_circle(int cx, int cy, int radius, uint8_t color) {
    int x = radius;
    int y = 0;
    int err = 0;

    while (x >= y) {
        gfx_hline(cx - x, cy + y, 2 * x + 1, color);
        gfx_hline(cx - x, cy - y, 2 * x + 1, color);
        gfx_hline(cx - y, cy + x, 2 * y + 1, color);
        gfx_hline(cx - y, cy - x, 2 * y + 1, color);

        if (err <= 0) {
            y += 1;
            err += 2 * y + 1;
        }
        if (err > 0) {
            x -= 1;
            err -= 2 * x + 1;
        }
    }
}

// Opaque BitBlt with full boundary clipping
TCM_FUNC void gfx_bitblit(int dx, int dy, int w, int h, const uint8_t *src, int src_stride) {
    if (src_stride <= 0) src_stride = w;

    // Boundary Clipping
    if (dx < 0) { w += dx; src -= dx; dx = 0; }
    if (dy < 0) { h += dy; src -= dy * src_stride; dy = 0; }
    if (dx + w > GFX_WIDTH)  { w = GFX_WIDTH - dx; }
    if (dy + h > GFX_HEIGHT) { h = GFX_HEIGHT - dy; }
    if (w <= 0 || h <= 0) return;

    uint8_t *dest = gfx_get_draw_buffer() + (dy * GFX_WIDTH) + dx;

    for (int row = 0; row < h; row++) {
        memcpy(dest, src, w);
        dest += GFX_WIDTH;
        src += src_stride;
    }
}

// Transparent BitBlt (Color Keying) with clipping
TCM_FUNC void gfx_bitblit_transparent(int dx, int dy, int w, int h, const uint8_t *src, int src_stride, uint8_t key_color) {
    if (src_stride <= 0) src_stride = w;

    if (dx < 0) { w += dx; src -= dx; dx = 0; }
    if (dy < 0) { h += dy; src -= dy * src_stride; dy = 0; }
    if (dx + w > GFX_WIDTH)  { w = GFX_WIDTH - dx; }
    if (dy + h > GFX_HEIGHT) { h = GFX_HEIGHT - dy; }
    if (w <= 0 || h <= 0) return;

    uint8_t *dest = gfx_get_draw_buffer() + (dy * GFX_WIDTH) + dx;

    for (int row = 0; row < h; row++) {
        for (int col = 0; col < w; col++) {
            uint8_t px = src[col];
            if (px != key_color) {
                dest[col] = px;
            }
        }
        dest += GFX_WIDTH;
        src += src_stride;
    }
}
