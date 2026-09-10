#include <stdint.h>

#define gpio_data   *((volatile uint32_t *)0x10000004)
#define gpio_oe     *((volatile uint32_t *)0x10000008)

#define uart_data   *((volatile uint32_t *)0x10000018)

#define uart_status *((volatile uint32_t *)0x1000001C)
#define uart_status_tx_fifo_full  1
#define uart_status_tx_fifo_empty 2
#define uart_status_rx_read_ready 4

#define vga_mem ((volatile uint32_t *)0x04000000)

void bios_main(void)
{
	// hello message padded with NULs for our simple test
    char *msg = "Hello world\n\r\x00\x00";
    int x;
    
    // write message to first row (white on black font, two chars at a time)
    for (x = 0; msg[x]; x += 2) {
        vga_mem[x>>1] = 0xF000F000 | (msg[x]) | ((uint32_t)msg[x+1] << 16);
    }
    // copy first row to second row
    for (x = 0; x < 160; x += 4) {
		vga_mem[(160 + x) >> 2] = vga_mem[x >> 2];
	}
	
	// write to GPIO
    gpio_oe   = 0xFFFFFFFF;
    gpio_data = 0x55AA5AA5;

	// endlessly write to UART
    x = 0;
    for (;;) {
        if (!(uart_status & uart_status_tx_fifo_full)) {
            uart_data = msg[x++];
            if (!msg[x]) {
                x = 0;
            }
        }
    }
}
