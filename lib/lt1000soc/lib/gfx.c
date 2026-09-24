#include "lt1000.h"

#include "gfx.h"

// --- Hardware Control ---
TCM_FUNC(gfx_set_mode) void gfx_set_mode(int mode) {
    if (mode) {
        VGA_CTRL |= VGA_CTRL_GFX_MODE;
    } else {
        VGA_CTRL &= ~VGA_CTRL_GFX_MODE;
    }
}

// Wait for VBLANK edge (low-to-high transition)
TCM_FUNC(gfx_vsync) void gfx_vsync(void) {
    while (VGA_CTRL & VGA_CTRL_VBLANK);  // Wait if currently in VBLANK
    while (!(VGA_CTRL & VGA_CTRL_VBLANK)); // Wait until VBLANK starts
}

// Wait for HBLANK edge
TCM_FUNC(gfx_hsync) void gfx_hsync(void) {
    while (VGA_CTRL & VGA_CTRL_HBLANK);
    while (!(VGA_CTRL & VGA_CTRL_HBLANK));
}

// --- Polygon Rendering ---

TCM_FUNC(gfx_triangle) void gfx_triangle(int x0, int y0, int x1, int y1, int x2, int y2, uint8_t color) {
    gfx_line(x0, y0, x1, y1, color);
    gfx_line(x1, y1, x2, y2, color);
    gfx_line(x2, y2, x0, y0, color);
}

// Standard Standard Flat-Top / Flat-Bottom Scanline Rasterizer
TCM_FUNC(gfx_fill_triangle) void gfx_fill_triangle(int x0, int y0, int x1, int y1, int x2, int y2, uint8_t color) {
    // Sort vertices by Y (y0 <= y1 <= y2)
    if (y0 > y1) { int t; t=x0; x0=x1; x1=t; t=y0; y0=y1; y1=t; }
    if (y1 > y2) { int t; t=x1; x1=x2; x2=t; t=y1; y1=y2; y2=t; }
    if (y0 > y1) { int t; t=x0; x0=x1; x1=t; t=y0; y0=y1; y1=t; }

    if (y0 == y2) return; // Degenerate triangle

    int total_height = y2 - y0;

    for (int i = 0; i < total_height; i++) {
        int second_half = i > (y1 - y0) || y1 == y0;
        int segment_height = second_half ? (y2 - y1) : (y1 - y0);
        
        if (segment_height == 0) continue;

        int alpha = (i << 8) / total_height;
        int beta  = ((i - (second_half ? (y1 - y0) : 0)) << 8) / segment_height;

        int ax = x0 + (((x2 - x0) * alpha) >> 8);
        int bx = second_half ? (x1 + (((x2 - x1) * beta) >> 8)) : (x0 + (((x1 - x0) * beta) >> 8));

        if (ax > bx) { int t = ax; ax = bx; bx = t; }
        gfx_hline(ax, y0 + i, bx - ax + 1, color);
    }
}

// --- Sprite Sheet Blitting ---

// Blit a sub-region (sx, sy, sw, sh) from a larger texture/atlas sheet
TCM_FUNC(gfx_bitblit_rect) void gfx_bitblit_rect(int dx, int dy, int sx, int sy, int sw, int sh, 
                               const uint8_t *src, int src_stride, uint8_t key_color) {
    const uint8_t *sub_src = src + (sy * src_stride) + sx;
    gfx_bitblit_transparent(dx, dy, sw, sh, sub_src, src_stride, key_color);
}

// --- 8x8 System Font Engine ---

// Standard 8x8 ASCII font bitmap data (0x20 space through 0x7E ~)
static const uint8_t font8x8_basic[95][8] = {
    {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}, // ' '
    {0x18,0x3C,0x3C,0x18,0x18,0x00,0x18,0x00}, // '!'
    {0x36,0x36,0x00,0x00,0x00,0x00,0x00,0x00}, // '"'
    {0x36,0x36,0x7F,0x36,0x7F,0x36,0x36,0x00}, // '#'
    {0x0C,0x3E,0x03,0x1E,0x30,0x1F,0x0C,0x00}, // '$'
    {0x00,0x63,0x66,0x0C,0x18,0x33,0x63,0x00}, // '%'
    {0x1C,0x36,0x1C,0x3E,0x6B,0x6C,0x3B,0x00}, // '&'
    {0x18,0x18,0x30,0x00,0x00,0x00,0x00,0x00}, // '\''
    {0x0C,0x18,0x30,0x30,0x30,0x18,0x0C,0x00}, // '('
    {0x30,0x18,0x0C,0x0C,0x0C,0x18,0x30,0x00}, // ')'
    {0x00,0x18,0x7E,0x3C,0x7E,0x18,0x00,0x00}, // '*'
    {0x00,0x18,0x18,0x7E,0x18,0x18,0x00,0x00}, // '+'
    {0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x30}, // ','
    {0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00}, // '-'
    {0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x00}, // '.'
    {0x00,0x03,0x06,0x0C,0x18,0x30,0x60,0x00}, // '/'
    {0x3E,0x63,0x67,0x6F,0x7B,0x63,0x3E,0x00}, // '0'
    {0x0C,0x1C,0x0C,0x0C,0x0C,0x0C,0x3E,0x00}, // '1'
    {0x3E,0x63,0x06,0x1C,0x30,0x60,0x7F,0x00}, // '2'
    {0x3E,0x63,0x06,0x1C,0x06,0x63,0x3E,0x00}, // '3'
    {0x0C,0x1C,0x3C,0x6C,0x7F,0x0C,0x0C,0x00}, // '4'
    {0x7F,0x60,0x7C,0x06,0x06,0x63,0x3E,0x00}, // '5'
    {0x1C,0x30,0x60,0x7C,0x63,0x63,0x3E,0x00}, // '6'
    {0x7F,0x03,0x06,0x0C,0x18,0x18,0x18,0x00}, // '7'
    {0x3E,0x63,0x63,0x3E,0x63,0x63,0x3E,0x00}, // '8'
    {0x3E,0x63,0x63,0x3E,0x03,0x06,0x38,0x00}, // '9'
    {0x00,0x18,0x18,0x00,0x00,0x18,0x18,0x00}, // ':'
    {0x00,0x18,0x18,0x00,0x00,0x18,0x18,0x30}, // ';'
    {0x0C,0x18,0x30,0x60,0x30,0x18,0x0C,0x00}, // '<'
    {0x00,0x00,0x7E,0x00,0x7E,0x00,0x00,0x00}, // '='
    {0x30,0x18,0x0C,0x06,0x0C,0x18,0x30,0x00}, // '>'
    {0x3E,0x63,0x06,0x0C,0x18,0x00,0x18,0x00}, // '?'
    {0x3E,0x63,0x6F,0x6B,0x6F,0x60,0x3E,0x00}, // '@'
    {0x18,0x3C,0x66,0x66,0x7E,0x66,0x66,0x00}, // 'A'
    {0x7C,0x66,0x66,0x7C,0x66,0x66,0x7C,0x00}, // 'B'
    {0x3C,0x66,0x60,0x60,0x60,0x66,0x3C,0x00}, // 'C'
    {0x78,0x6C,0x66,0x66,0x66,0x6C,0x78,0x00}, // 'D'
    {0x7E,0x60,0x60,0x7C,0x60,0x60,0x7E,0x00}, // 'E'
    {0x7E,0x60,0x60,0x7C,0x60,0x60,0x60,0x00}, // 'F'
    {0x3C,0x66,0x60,0x6E,0x66,0x66,0x3B,0x00}, // 'G'
    {0x66,0x66,0x66,0x7E,0x66,0x66,0x66,0x00}, // 'H'
    {0x3C,0x18,0x18,0x18,0x18,0x18,0x3C,0x00}, // 'I'
    {0x1E,0x0C,0x0C,0x0C,0x0C,0x6C,0x38,0x00}, // 'J'
    {0x66,0x6C,0x78,0x70,0x78,0x6C,0x66,0x00}, // 'K'
    {0x60,0x60,0x60,0x60,0x60,0x60,0x7E,0x00}, // 'L'
    {0x63,0x77,0x7F,0x6B,0x63,0x63,0x63,0x00}, // 'M'
    {0x66,0x76,0x7E,0x7E,0x6E,0x66,0x66,0x00}, // 'N'
    {0x3C,0x66,0x66,0x66,0x66,0x66,0x3C,0x00}, // 'O'
    {0x7C,0x66,0x66,0x7C,0x60,0x60,0x60,0x00}, // 'P'
    {0x3C,0x66,0x66,0x66,0x66,0x3C,0x0E,0x00}, // 'Q'
    {0x7C,0x66,0x66,0x7C,0x78,0x6C,0x66,0x00}, // 'R'
    {0x3C,0x66,0x60,0x3C,0x06,0x66,0x3C,0x00}, // 'S'
    {0x7E,0x18,0x18,0x18,0x18,0x18,0x18,0x00}, // 'T'
    {0x66,0x66,0x66,0x66,0x66,0x66,0x3C,0x00}, // 'U'
    {0x66,0x66,0x66,0x66,0x66,0x3C,0x18,0x00}, // 'V'
    {0x63,0x63,0x63,0x6B,0x7F,0x77,0x63,0x00}, // 'W'
    {0x66,0x66,0x3C,0x18,0x3C,0x66,0x66,0x00}, // 'X'
    {0x66,0x66,0x66,0x3C,0x18,0x18,0x18,0x00}, // 'Y'
    {0x7E,0x06,0x0C,0x18,0x30,0x60,0x7E,0x00}, // 'Z'
};

TCM_FUNC(gfx_draw_char) void gfx_draw_char(int x, int y, char c, uint8_t color, uint8_t bg_color, int transparent_bg) {
    if (c < 32 || c > 90) c = '?'; // Cap uppercase/basic printable ascii
    const uint8_t *glyph = font8x8_basic[c - 32];

    for (int row = 0; row < 8; row++) {
        uint8_t bits = glyph[row];
        for (int col = 0; col < 8; col++) {
            if (bits & (0x80 >> col)) {
                gfx_putpixel(x + col, y + row, color);
            } else if (!transparent_bg) {
                gfx_putpixel(x + col, y + row, bg_color);
            }
        }
    }
}

TCM_FUNC(gfx_puts) void gfx_puts(int x, int y, const char *str, uint8_t color, uint8_t bg_color, int transparent_bg) {
    int cur_x = x;
    while (*str) {
        if (*str == '\n') {
            cur_x = x;
            y += 8;
        } else {
            gfx_draw_char(cur_x, y, *str, color, bg_color, transparent_bg);
            cur_x += 8;
        }
        str++;
    }
}

// Helper to get active off-screen buffer
TCM_FUNC(gfx_get_draw_buffer) uint8_t *gfx_get_draw_buffer(void) {
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
TCM_FUNC(gfx_flip_page) uint8_t *gfx_flip_page(void) {
    VGA_CTRL ^= VGA_CTRL_PAGE_SEL;
    return gfx_get_draw_buffer();
}

// Fast clear using memset
TCM_FUNC(gfx_clear) void gfx_clear(uint8_t color) {
    memset(gfx_get_draw_buffer(), color, GFX_WIDTH * GFX_HEIGHT);
}

// Single pixel plot with bounds checking
TCM_FUNC(gfx_putpixel) void gfx_putpixel(int x, int y, uint8_t color) {
    if ((unsigned int)x >= GFX_WIDTH || (unsigned int)y >= GFX_HEIGHT) return;
    uint8_t *buf = gfx_get_draw_buffer();
    buf[y * GFX_WIDTH + x] = color;
}

// Fast horizontal line
TCM_FUNC(gfx_hline) void gfx_hline(int x, int y, int w, uint8_t color) {
    if (y < 0 || y >= GFX_HEIGHT || w <= 0) return;
    if (x < 0) { w += x; x = 0; }
    if (x + w > GFX_WIDTH) { w = GFX_WIDTH - x; }
    if (w <= 0) return;

    uint8_t *dest = gfx_get_draw_buffer() + (y * GFX_WIDTH) + x;
    memset(dest, color, w);
}

// Fast vertical line
TCM_FUNC(gfx_vline) void gfx_vline(int x, int y, int h, uint8_t color) {
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
TCM_FUNC(gfx_line) void gfx_line(int x0, int y0, int x1, int y1, uint8_t color) {
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
TCM_FUNC(gfx_rect) void gfx_rect(int x, int y, int w, int h, uint8_t color) {
    if (w <= 0 || h <= 0) return;
    gfx_hline(x, y, w, color);
    gfx_hline(x, y + h - 1, w, color);
    gfx_vline(x, y, h, color);
    gfx_vline(x + w - 1, y, h, color);
}

// Filled rectangle
TCM_FUNC(gfx_fill_rect) void gfx_fill_rect(int x, int y, int w, int h, uint8_t color) {
    for (int i = 0; i < h; i++) {
        gfx_hline(x, y + i, w, color);
    }
}

// Midpoint Circle Algorithm (Outline)
TCM_FUNC(gfx_circle) void gfx_circle(int cx, int cy, int radius, uint8_t color) {
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
TCM_FUNC(gfx_fill_circle) void gfx_fill_circle(int cx, int cy, int radius, uint8_t color) {
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
TCM_FUNC(gfx_bitblit) void gfx_bitblit(int dx, int dy, int w, int h, const uint8_t *src, int src_stride) {
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
TCM_FUNC(gfx_bitblit_transparent) void gfx_bitblit_transparent(int dx, int dy, int w, int h, const uint8_t *src, int src_stride, uint8_t key_color) {
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

/**
 * @brief Converts an 8x8 row-major image into a 12x8 pre-shifted sprite structure.
 * 
 * @param src_8x8 Pointer to 64 bytes of row-major pixel data.
 * @param dst_sprite Pointer to target Sprite12x8 destination structure.
 */
void gfx_convert_8x8_to_sprite12x8(const uint8_t *src_8x8, Sprite12x8 *dst_sprite) {
    for (int shift = 0; shift < 4; shift++) {
        for (int row = 0; row < 8; row++) {
            uint8_t row_bytes[12];

            // Fill 12-byte wide row with transparent padding
            memset(row_bytes, 0xE3, 12);

            // Copy 8 pixels from source into the shifted horizontal offset
            for (int col = 0; col < 8; col++) {
                row_bytes[shift + col] = src_8x8[row * 8 + col];
            }

            // Pack 12 bytes into 3 dwords (uint32_t) for fast 32-bit stores
            // Assumes little-endian target: byte 0 is LSB, byte 3 is MSB
            for (int dw = 0; dw < 3; dw++) {
                int b = dw * 4;
                dst_sprite->phase[shift][row][dw] = 
                    ((uint32_t)row_bytes[b + 0] << 0)  |
                    ((uint32_t)row_bytes[b + 1] << 8)  |
                    ((uint32_t)row_bytes[b + 2] << 16) |
                    ((uint32_t)row_bytes[b + 3] << 24);
            }
        }
    }
}

TCM_FUNC(gfx_draw_sprite_8x8) void gfx_draw_sprite_8x8(uint32_t *vram_base, const Sprite12x8 *sprite, int x, int y) {
    // Basic screen bounds check (Y dimension)
    if (y < 0 || y > 192) return; 

    // 1. Select pre-shifted phase based on low 2 bits of X
    int shift = x & 3;
    const uint32_t *src = &sprite->phase[shift][0][0];

    // 2. Align VRAM destination pointer to 32-bit word boundary
    // (y * 80 words per scanline + word index for X)
    uint32_t *dst = vram_base + (y * 80) + (x >> 2);

    // 3. Fast Path: Fully on-screen horizontally (x >= 0 and x <= 308)
    if (x >= 0 && x <= (320 - 12)) {
        // Unrolled 8 rows x 3 dwords = 24 stores
        dst[0]   = src[0];   dst[1]   = src[1];   dst[2]   = src[2];
        dst[80]  = src[3];   dst[81]  = src[4];   dst[82]  = src[5];
        dst[160] = src[6];   dst[161] = src[7];   dst[162] = src[8];
        dst[240] = src[9];   dst[241] = src[10];  dst[242] = src[11];
        dst[320] = src[12];  dst[321] = src[13];  dst[322] = src[14];
        dst[400] = src[15];  dst[401] = src[16];  dst[402] = src[17];
        dst[480] = src[18];  dst[481] = src[19];  dst[482] = src[20];
        dst[560] = src[21];  dst[561] = src[22];  dst[562] = src[23];
        return;
    }

    // 4. Edge Clipping Path (Left / Right Screen Edges)
    int word_x = x >> 2;
    for (int r = 0; r < 8; r++) {
        if (word_x >= 0 && word_x < 80)      dst[0] = src[0];
        if (word_x + 1 >= 0 && word_x + 1 < 80) dst[1] = src[1];
        if (word_x + 2 >= 0 && word_x + 2 < 80) dst[2] = src[2];
        
        dst += 80;
        src += 3;
    }
}

TCM_FUNC(gfx_draw_tile_map) void gfx_draw_tile_map(uint32_t *fb, const uint8_t *map, const uint32_t *tile_gfx) {
    // fb is uint32_t* targeting VRAM or TCM (320x200 = 80 words per line)
    
	uint32_t *row_ptr = fb;
    for (int y = 0; y < 25; y++) {
		uint32_t *dst = row_ptr; // Base word of tile (x, y)
        for (int x = 0; x < 40; x++) {
            uint8_t tile_id = map[y * 40 + x];
            const uint32_t *tex = &tile_gfx[tile_id << 4]; // 16 words per 8x8 tile
            
            // Row 0
            dst[0]      = tex[0];  dst[1]      = tex[1];
            // Row 1
            dst[80]     = tex[2];  dst[81]     = tex[3];
            // Row 2
            dst[160]    = tex[4];  dst[161]    = tex[5];
            // Row 3
            dst[240]    = tex[6];  dst[241]    = tex[7];
            // Row 4
            dst[320]    = tex[8];  dst[321]    = tex[9];
            // Row 5
            dst[400]    = tex[10]; dst[401]    = tex[11];
            // Row 6
            dst[480]    = tex[12]; dst[481]    = tex[13];
            // Row 7
            dst[560]    = tex[14]; dst[561]    = tex[15];
            
            dst += 2;
        }
		row_ptr += 640; // Base of this 8-pixel tall tile row
    }
}

TCM_FUNC(gfx_draw_tile_map_overlay) void gfx_draw_tile_map_overlay(
    uint32_t *fb,           // Base pointer to VRAM frame buffer
    const uint8_t *map,     // Pointer to mini/cropped tile map array
    const uint32_t *tile_gfx, // Base pointer to 8x8 tile graphics
    int start_x, int start_y, // Screen tile coordinates (e.g., tile X=5, Y=2)
    int map_w, int map_h    // Dimensions of the mini tilemap (in tiles)
) {
    // 1. Calculate destination starting scanline word address in VRAM
    uint32_t *row_ptr = fb + (start_y * 640) + (start_x << 1);

    for (int y = 0; y < map_h; y++) {
        // Quick vertical bounds check against 320x200 screen (25 tiles tall)
        if ((start_y + y) >= 0 && (start_y + y) < 25) {
            
            uint32_t *dst = row_ptr;
            for (int x = 0; x < map_w; x++) {
                // Quick horizontal bounds check (40 tiles wide)
                if ((start_x + x) >= 0 && (start_x + x) < 40) {
                    
                    size_t tile_id = map[y * map_w + x];
                    const uint32_t *tex = &tile_gfx[tile_id << 4];

                    // Unrolled 8x8 tile store (Hardware byte masking handles 0xE3 transparency!)
                    dst[0]   = tex[0];  dst[1]   = tex[1];
                    dst[80]  = tex[2];  dst[81]  = tex[3];
                    dst[160] = tex[4];  dst[161] = tex[5];
                    dst[240] = tex[6];  dst[241] = tex[7];
                    dst[320] = tex[8];  dst[321] = tex[9];
                    dst[400] = tex[10]; dst[401] = tex[11];
                    dst[480] = tex[12]; dst[481] = tex[13];
                    dst[560] = tex[14]; dst[561] = tex[15];
                }
                dst += 2; // Move 2 words right in VRAM
            }
        }
        row_ptr += 640; // Advance down 8 scanlines (8 * 80 words)
    }
}
