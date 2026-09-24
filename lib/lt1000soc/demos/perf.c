#include "lt1000.h"

TCM_FUNC(demo) void demo(void)
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
	gfx_draw_tile_map(VGA_ADDR, VGA_ADDR, VGA_ADDR);
	t1 = TIMER - t1;
	printf("draw_tile_map(ALL_VGA), took %lu cycles\n", t1);

	t1 = TIMER;
	gfx_draw_tile_map(VGA_ADDR, PSRAM_ADDR, VGA_ADDR);
	t1 = TIMER - t1;
	printf("draw_tile_map(tile_map=PSRAM), took %lu cycles\n", t1);

	t1 = TIMER;
	gfx_draw_tile_map(VGA_ADDR, VGA_ADDR, PSRAM_ADDR+0x2000);
	t1 = TIMER - t1;
	printf("draw_tile_map(tile_map=TCM, tile_data=PSRAM+0x2000), took %lu cycles\n", t1);

	t1 = TIMER;
	gfx_draw_tile_map(VGA_ADDR, PSRAM_ADDR+0x4000, PSRAM_ADDR+0x6000);
	t1 = TIMER - t1;
	printf("draw_tile_map(tile_map=PSRAM+0x4000, tile_data=PSRAM+0x6000), took %lu cycles\n", t1);

	t1 = TIMER;
	gfx_draw_sprite_8x8(VGA_ADDR, TCM_ADDR, 0, 0);
	t1 = TIMER - t1;
	printf("draw_sprite_8x8(sprite=TCM), took %lu cycles\n", t1);

	t1 = TIMER;
	gfx_draw_sprite_8x8(VGA_ADDR, PSRAM_ADDR+0x8000, 0, 0);
	t1 = TIMER - t1;
	printf("draw_sprite_8x8(sprite=PSRAM+0x8000), took %lu cycles\n", t1);

	t1 = TIMER;
	gfx_draw_tile_map_overlay(VGA_ADDR, PSRAM_ADDR+0xA000, PSRAM_ADDR+0xC000, 0, 20, 40, 5);
	t1 = TIMER - t1;
	printf("draw_tile_map_overlay(ALL=PSRAM at offsets, bottom 5x40), took %lu cycles\n", t1);
}

void main(void)
{
	demo();
}

