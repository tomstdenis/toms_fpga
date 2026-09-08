#include <stdint.h>

#define uart_data   *((volatile uint32_t *)0x10000018)

#define uart_status *((volatile uint32_t *)0x1000001C)
#define uart_status_tx_fifo_full  1
#define uart_status_tx_fifo_empty 2
#define uart_status_rx_read_ready 4

void bios_main(void)
{
    char *msg = "Hello world\n\r";
    int x;
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