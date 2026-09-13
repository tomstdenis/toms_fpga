#include <stdint.h>

#define UART_DATA           ((volatile uint32_t *)0x10000018)
#define UART_STATUS         ((volatile uint32_t *)0x1000001C)
#define UART_STATUS_TX_FULL  1
#define UART_STATUS_TX_EMPTY 2
#define UART_STATUS_RX_READY 4

#define VGA_FB8             ((volatile uint8_t  *)0x04000000)
#define VGA_FB32            ((volatile uint32_t *)0x04000000)
#define VGA_CTRL            ((volatile uint32_t *)0x10000020)

#define WIDTH               320
#define HEIGHT              200
#define PAGE_SIZE           0x10000 

#define CTRL_MODE_GFX       (1 << 0)
#define CTRL_PAGE_1         (1 << 1)
#define CTRL_VBLANK         (1 << 3)
#define CTRL_HBLANK         (1 << 2) // Assuming Bit 2 reflects HBLANK status

static inline void wait_vblank(void) {
    while (!(*VGA_CTRL & CTRL_VBLANK));
}

static inline void wait_vblank_end(void) {
    while (*VGA_CTRL & CTRL_VBLANK);
}

static inline void wait_hblank_pulse(int wait_to_exit) {
    while (!(*VGA_CTRL & CTRL_HBLANK));
    while (wait_to_exit && *VGA_CTRL & CTRL_HBLANK);
}

void draw_page_0_pattern(uint8_t shift) {
    volatile uint8_t *page0 = VGA_FB8;
    for (int y = 0; y < HEIGHT; y++) {
        uint8_t color = (y + shift) & 0x3F;
        for (int x = 0; x < WIDTH; x++) {
            page0[y * WIDTH + x] = color;
        }
    }
}

void draw_page_1_pattern(uint8_t shift) {
    // Page 1 memory location
    volatile uint8_t *page1 = VGA_FB8 + PAGE_SIZE;

    // Clear entire page first (80 cols x 25 rows x 2 bytes = 4000 bytes)
    for (int i = 0; i < 4000; i++) {
        page1[i] = 0;
    }

    const char *msg = "=== LITTLE TIMMY TEXT MODE CONSOLE ===";
    
    // IRGBirgb format: 
    // Foreground: 0b1111 (Bright White) | Background: 0b0001 (Dark Blue)
    uint8_t color_attr = (0b1111 << 4) | 0b0001; 

    // Write text string across row 12
    int col = 0;
    while (msg[col] != '\0' && col < 80) {
        page1[col * 2]     = msg[col];      // Byte 0: ASCII Character
        page1[col * 2 + 1] = color_attr;    // Byte 1: IRGBirgb Color Attribute
        col++;
    }

    // Add a pulsing animated indicator at the end of the line using 'shift'
    uint8_t pulse_color = ((shift & 0x0F) << 4) | 0b0000; // Pulsing FG, Black BG
    page1[(col + 2) * 2]     = 0xFE;          // Square block / bullet glyph
    page1[(col + 2) * 2 + 1] = pulse_color;

}
void main(void) {
    uint8_t frame_counter = 0;

    // Set graphics mode initially on Page 0
    *VGA_CTRL = CTRL_MODE_GFX;

	// Update independent framebuffers
	draw_page_0_pattern(frame_counter);
	draw_page_1_pattern(frame_counter);

    while (1) {

        // 1. Sync to start of active frame display
        wait_vblank();
        wait_vblank_end();

        // 2. Count HBLANK pulses to hit around middle of screen
        for (int line = 0; line < 192; line++) {
            wait_hblank_pulse((line == 191) ? 0 : 1);
        }
        
        // 3. MID-FRAME FLIP: Force Page 1 display for bottom half of monitor
        *VGA_CTRL = CTRL_PAGE_1;

        // 4. Wait for frame to finish in VBLANK, then reset to Page 0 for top half
        wait_vblank();
        *VGA_CTRL = CTRL_MODE_GFX;

        frame_counter++;

        // uart echo
        if (*UART_STATUS & UART_STATUS_RX_READY) {
			uint32_t v = *UART_DATA;
			*UART_DATA = v;
			if (v == 27) { 
				void (*bios_entry)(void) = (void (*)(void))0x01000000;
				bios_entry();
			}
		}
    }
}
