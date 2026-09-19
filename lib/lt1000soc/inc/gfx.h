#ifndef GFX_H
#define GFX_H

#define GFX_WIDTH  320
#define GFX_HEIGHT 200
#define GFX_PAGE_SIZE 0x10000

// Hardware & Synchronization
void gfx_set_mode(int mode);
void gfx_vsync(void);
void gfx_hsync(void);
uint8_t *gfx_flip_page(void);
uint8_t *gfx_get_draw_buffer(void);

// Primitives
void gfx_clear(uint8_t color);
void gfx_putpixel(int x, int y, uint8_t color);
void gfx_line(int x0, int y0, int x1, int y1, uint8_t color);
void gfx_hline(int x, int y, int w, uint8_t color);
void gfx_vline(int x, int y, int h, uint8_t color);
void gfx_rect(int x, int y, int w, int h, uint8_t color);
void gfx_fill_rect(int x, int y, int w, int h, uint8_t color);
void gfx_circle(int cx, int cy, int radius, uint8_t color);
void gfx_fill_circle(int cx, int cy, int radius, uint8_t color);

// Polygons
void gfx_triangle(int x0, int y0, int x1, int y1, int x2, int y2, uint8_t color);
void gfx_fill_triangle(int x0, int y0, int x1, int y1, int x2, int y2, uint8_t color);

// Advanced Blitting
void gfx_bitblit(int dx, int dy, int w, int h, const uint8_t *src, int src_stride);
void gfx_bitblit_transparent(int dx, int dy, int w, int h, const uint8_t *src, int src_stride, uint8_t key_color);
void gfx_bitblit_rect(int dx, int dy, int sx, int sy, int sw, int sh, const uint8_t *src, int src_stride, uint8_t key_color);

// Text Rendering (Embedded 8x8 font)
void gfx_draw_char(int x, int y, char c, uint8_t color, uint8_t bg_color, int transparent_bg);
void gfx_puts(int x, int y, const char *str, uint8_t color, uint8_t bg_color, int transparent_bg);

#endif
