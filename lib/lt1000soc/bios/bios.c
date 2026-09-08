#include <stdint.h>

#define uart_data   *((volatile uint32_t *)0x10000018)
#define uart_status *((volatile uint32_t *)0x1000001C)

void bios_main(void)
{
    const char *msg = "Hello world\n";
    int x;
    x = 0;
    for (;;) {
        if (!(uart_status & 1)) {
            uart_data = msg[x++];
            if (!msg[x]) {
                x = 0;
            }
        }
    }
}