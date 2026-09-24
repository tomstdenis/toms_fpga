#ifndef GFX_H
#define GFX_H

// Pre-calculated sprite struct: 4 shifted phases, each 12x8 bytes (24 dwords)
typedef struct {
    uint32_t phase[4][8][3]; // [shift 0..3][row 0..7][dword 0..2]
} Sprite12x8;

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

// sprite and tile
// convert an 8x8 row major sprite to a precomputed phase aligned Sprite12x8
void gfx_convert_8x8_to_sprite12x8(const uint8_t *src_8x8, Sprite12x8 *dst_sprite);

// draw a sprite at any x/y where it won't clip on 
void gfx_draw_sprite_8x8(uint32_t *vram_base, const Sprite12x8 *sprite, int x, int y);

// draw a 40x25 map of 8x8 tiles indexed by map into tile_gfx (which is an array of 64 byte tiles each in row major order for an 8x8 tile)
void gfx_draw_tile_map(uint32_t *fb, const uint8_t *map, const uint32_t *tile_gfx);

// draw a tile map windowed style (useful for overlays especially when VGA_CTRL_WRITE_MASK is set where 0xE3 pixels are transparent)
void gfx_draw_tile_map_overlay(
    uint32_t *fb,           // Base pointer to VRAM frame buffer
    const uint8_t *map,     // Pointer to mini/cropped tile map array
    const uint32_t *tile_gfx, // Base pointer to 8x8 tile graphics
    int start_x, int start_y, // Screen tile coordinates (e.g., tile X=5, Y=2)
    int map_w, int map_h    // Dimensions of the mini tilemap (in tiles)
);

#endif
