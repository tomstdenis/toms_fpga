#include "lt1000.h"

// Pre-calculated sprite struct: 4 shifted phases, each 12x8 bytes (24 dwords)
typedef struct {
    uint32_t phase[4][8][3]; // [shift 0..3][row 0..7][dword 0..2]
} Sprite12x8;

TCM_FUNC void draw_sprite_8x8(uint32_t *vram_base, const Sprite12x8 *sprite, int x, int y) {
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
TCM_FUNC void draw_tile_map_unrolled(uint32_t *fb, const uint8_t *map, const uint32_t *tile_gfx) {
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

TCM_FUNC void draw_tile_map_overlay(
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

TCM_FUNC void demo(void)
{
	volatile uint32_t *p1, *p2, t1;
	uint32_t x;
	
	getch();
	
	// time TCM to VGA copy
	t1 = TIMER;
	p1 = VGA_ADDR;
	p2 = TCM_ADDR;
	for (x = 0; x < ((320 * 200) / 4); x++) {
		*p1++ = *p2++;
	}
	t1 = TIMER - t1;
	printf("unroll1, TCM => VGA copy took %lu cycles\n", t1);

	// time TCM to VGA copy
	t1 = TIMER;
	p1 = VGA_ADDR;
	p2 = TCM_ADDR;
	for (x = 0; x < ((320 * 200) / 16); x++) {
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
	}
	t1 = TIMER - t1;
	printf("unroll4, TCM => VGA copy took %lu cycles\n", t1);

	// time TCM to VGA copy
	t1 = TIMER;
	p1 = VGA_ADDR;
	p2 = TCM_ADDR;
	for (x = 0; x < ((320 * 200) / 32); x++) {
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
	}
	t1 = TIMER - t1;
	printf("unroll8, TCM => VGA copy took %lu cycles\n", t1);

	// time TCM to VGA copy
	t1 = TIMER;
	p1 = VGA_ADDR;
	p2 = TCM_ADDR;
	for (x = 0; x < ((320 * 200) / 64); x++) {
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;

		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
	}
	t1 = TIMER - t1;
	printf("unroll16, TCM => VGA copy took %lu cycles\n", t1);

	// time TCM to VGA copy
	t1 = TIMER;
	p1 = VGA_ADDR;
	p2 = TCM_ADDR;
	for (x = 0; x < ((320 * 200) / 128); x++) {
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;

		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;

		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;

		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
	}
	t1 = TIMER - t1;
	printf("unroll32, TCM => VGA copy took %lu cycles\n", t1);

	// time PSRAM to VGA copy
	t1 = TIMER;
	p1 = VGA_ADDR;
	p2 = PSRAM_ADDR;
	for (x = 0; x < ((320 * 200) / 128); x++) {
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;

		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;

		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;

		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
		*p1++ = *p2++;
	}
	t1 = TIMER - t1;
	printf("unroll32, PSRAM => VGA copy took %lu cycles\n", t1);

	t1 = TIMER;
	draw_tile_map_unrolled(VGA_ADDR, VGA_ADDR, VGA_ADDR);
	t1 = TIMER - t1;
	printf("draw_tile_map_unrolled(ALL_VGA), took %lu cycles\n", t1);

	t1 = TIMER;
	draw_tile_map_unrolled(VGA_ADDR, PSRAM_ADDR, VGA_ADDR);
	t1 = TIMER - t1;
	printf("draw_tile_map_unrolled(tile_map=PSRAM), took %lu cycles\n", t1);

	t1 = TIMER;
	draw_tile_map_unrolled(VGA_ADDR, VGA_ADDR, PSRAM_ADDR+0x2000);
	t1 = TIMER - t1;
	printf("draw_tile_map_unrolled(tile_map=TCM, tile_data=PSRAM+0x2000), took %lu cycles\n", t1);

	t1 = TIMER;
	draw_tile_map_unrolled(VGA_ADDR, PSRAM_ADDR+0x4000, PSRAM_ADDR+0x6000);
	t1 = TIMER - t1;
	printf("draw_tile_map_unrolled(tile_map=PSRAM+0x4000, tile_data=PSRAM+0x6000), took %lu cycles\n", t1);

	t1 = TIMER;
	draw_sprite_8x8(VGA_ADDR, TCM_ADDR, 0, 0);
	t1 = TIMER - t1;
	printf("draw_sprite_8x8(sprite=TCM), took %lu cycles\n", t1);

	t1 = TIMER;
	draw_sprite_8x8(VGA_ADDR, PSRAM_ADDR+0x8000, 0, 0);
	t1 = TIMER - t1;
	printf("draw_sprite_8x8(sprite=PSRAM+0x8000), took %lu cycles\n", t1);

	t1 = TIMER;
	draw_tile_map_overlay(VGA_ADDR, PSRAM_ADDR+0xA000, PSRAM_ADDR+0xC000, 0, 20, 40, 5);
	t1 = TIMER - t1;
	printf("draw_tile_map_overlay(ALL=PSRAM at offsets, bottom 5x40), took %lu cycles\n", t1);
}

void main(void)
{
	demo();
}

