#ifndef GFX_H
#define GFX_H

#define GFX_WIDTH  320
#define GFX_HEIGHT 200
#define GFX_PAGE_SIZE 0x10000

// Flips the display page and returns the pointer to the NEW backbuffer
uint8_t *gfx_flip_page(void);

// Gets a direct pointer to the current off-screen page buffer
uint8_t *gfx_get_draw_buffer(void);

// Basic Primitives
void gfx_clear(uint8_t color);
void gfx_putpixel(int x, int y, uint8_t color);
void gfx_line(int x0, int y0, int x1, int y1, uint8_t color);
void gfx_hline(int x, int y, int w, uint8_t color);
void gfx_vline(int x, int y, int h, uint8_t color);

// Rectangles
void gfx_rect(int x, int y, int w, int h, uint8_t color);
void gfx_fill_rect(int x, int y, int w, int h, uint8_t color);

// Circles
void gfx_circle(int cx, int cy, int radius, uint8_t color);
void gfx_fill_circle(int cx, int cy, int radius, uint8_t color);

// Blitting
void gfx_bitblit(int dx, int dy, int w, int h, const uint8_t *src, int src_stride);
void gfx_bitblit_transparent(int dx, int dy, int w, int h, const uint8_t *src, int src_stride, uint8_t key_color);

#endif
