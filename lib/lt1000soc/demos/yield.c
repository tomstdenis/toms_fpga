#include "lt1000.h"

uint32_t vblanks = 0;

static void gpio_irq(uint32_t data)
{
	puts("4th GPIO Positive Edge IRQ...\n\r");
}

static void uart_irq(uint32_t data)
{
	puts("Returning to BIOS from IRQ...\r\n");	
	void (*bios_entry)(void) = (void (*)(void))0x01000000;
	bios_entry();
}

static void vblank_irq(uint32_t data)
{
	++vblanks;
}

static void timer_3sec(uint32_t data)
{
	puts("Three second timer\r\n");
}

static void timer_1sec(uint32_t data)
{
	puts("One second timer (vblanks: ");
	puts_dec(vblanks);
	puts(")\r\n");
}

static void timer_250msec(uint32_t data)
{
	uint32_t d = GPIO_DATA;
	d = (d << 1) | (d >> 31);
	GPIO_DATA = d;
}	

void main(void)
{
	uint32_t x;
	
	yield_init();
	
	GPIO_DATA = ~1UL;
	GPIO_OE   = 0xFFFFFFFF;
	
	// wait for key press
	getc();
	
	for (x = 0; x < 5; x++) {
		puts("500ms delays...\n\r");
		delay_ms(500);
	}
	
	yield_sei();
	if (yield_add_irq(YIELD_IRQ_GPIO_POSEDGE, 1 << 4, gpio_irq) == 0) {
		puts("Installed GPIO IRQ...\n\r");
		if (yield_add_irq(YIELD_IRQ_UART_RX_READY, 0, uart_irq) == 0) {
			puts("Installed UART IRQ...\n\r");
			if (yield_add_irq(YIELD_IRQ_TIMER, yield_usec_to_cycles() * 1000UL * 250, timer_250msec) == 0) {
				puts("Installed 250ms timer IRQ...\n\r");
				if (yield_add_irq(YIELD_IRQ_VBLANK, 0, vblank_irq) == 0) {
					puts("Installed vblank IRQ...\n\r");
					if (yield_add_irq(YIELD_IRQ_TIMER, yield_usec_to_cycles() * 3000000UL, timer_3sec) == 0) {
						puts("Installed 3 second timer IRQ...\n\r");
						if (yield_add_irq(YIELD_IRQ_TIMER, yield_usec_to_cycles() * 1000000UL, timer_1sec) == 0) {
							puts("Installed 1 second timer IRQ...(hit key to exit)\n\r");
							for (;;) {
								// app code would go here
								
								// call this frequently to keep things moving
								yield();
							}
						}
					}
				}
			}
		}
	}
	puts("Could not install IRQ handler\n\rReturning to BIOS...\r\n");	
	void (*bios_entry)(void) = (void (*)(void))0x01000000;
	bios_entry();
}
