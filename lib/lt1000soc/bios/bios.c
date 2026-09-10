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
    char *msg = "Hello world\n\r\x00\x00";
    int x;
    for (x = 0; msg[x]; x += 2) {
        vga_mem[x>>1] = 0xF000F000 | (msg[x]) | ((uint32_t)msg[x+1] << 16);
    }
    x = 0;
    gpio_oe   = 0xFFFFFFFF;
    gpio_data = 0x55AA5AA5;
    for (;;) {
        if (!(uart_status & uart_status_tx_fifo_full)) {
            uart_data = msg[x++];
            if (!msg[x]) {
                x = 0;
            }
        }
    }
}