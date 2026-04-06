#include <stdio.h>

#include "font-8x8.c"

#if 0
unsigned char console_font_8x8[] = {

    /*
     * code=0, hex=0x00, ascii="^@"
     */
    0x00,  /* 00000000 */
    0x00,  /* 00000000 */
    0x00,  /* 00000000 */
    0x00,  /* 00000000 */
    0x00,  /* 00000000 */
    0x00,  /* 00000000 */
    0x00,  /* 00000000 */
    0x00,  /* 00000000 */
#endif

// we want to translate every '1' bit in the font into a 14bit case of symbol, x, y where x is the column and y is the row

int main(void)
{
	int x, y, z, i;
	
	i = 0;
	for(x = 0; x < 128; x++) {
		for (y = 0; y < 8; y++) {
			for (z = 0; z < 8; z++) {
				if (console_font_8x8[i] & (1 << z)) {
					printf("{8'd%d, 3'd%d, 3'd%d}: out = 1;\n", x, y, z);
				}
			}
			++i;
		}
	}
}
