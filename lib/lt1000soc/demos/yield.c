#include "lt1000.h"

static void timer_3sec(uint32_t data)
{
	puts("Three second timer\r\n");
}

static void timer_1sec(uint32_t data)
{
	puts("One second timer\r\n");
}


void main(void)
{
	uint32_t x;
	
	yield_init();
	
	// wait for key press
	getc();
	
	for (x = 0; x < 5; x++) {
		puts("500ms delays...\n\r");
		delay_ms(500);
	}
	
	// install IRQ for 3 sec delay
	if (yield_add_irq(YIELD_IRQ_TIMER, yield_usec_to_cycles() * 3000000UL, timer_3sec) == 0) {
		puts("Installed 3 second timer IRQ...\n\r");
		if (yield_add_irq(YIELD_IRQ_TIMER, yield_usec_to_cycles() * 1000000UL, timer_1sec) == 0) {
			puts("Installed 1 second timer IRQ...(hit key to exit)\n\r");
			while (!(UART_STATUS & UART_STATUS_RX_READY)) {
				// application loop goes here... 
				
				// call yield frequently to keep things moving
				yield();
			}
		}
	} else {
		puts("Could not install IRQ handler\n\r");
	}
	puts("Returning to BIOS...\r\n");	
	void (*bios_entry)(void) = (void (*)(void))0x01000000;
	bios_entry();
}
