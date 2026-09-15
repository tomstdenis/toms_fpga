#include "lt1000.h"

uint64_t yield_cycles;

static struct {
	uint32_t
		cycles_per_usec,
		cycles_per_msec,
		last_cycle_count,
		last_gpio_read,
		last_vga_read;
	int
		in_yield;
} yd;

static struct {
	enum yield_irq_type type;
	uint64_t       data, data2;
	void (*handler)(uint32_t data);
} irqs[MAX_IRQ];

void yield_init(void)
{
	uint32_t v;
	
	for (v = 0; v < MAX_IRQ; v++) {
		irqs[v].type = YIELD_IRQ_INACTIVE;
	}
	
	v                   = MCFG_FREQ_MHZ(MCFG_DATA) * 1000000UL; // frequency in Hz
	yd.cycles_per_usec  = v / 1000000;
	yd.cycles_per_msec  = v / 1000;
	yd.in_yield         = 0;
	yield_cycles        = 0;

	yd.last_gpio_read   = GPIO_DATA;
	yd.last_vga_read    = VGA_CTRL;
	yd.last_cycle_count = TIMER;
}

uint64_t yield_usec_to_cycles(void)
{
	return yd.cycles_per_usec;
}

void yield(void)
{
	uint32_t t;
	
	// update timer
	t = TIMER;
	yield_cycles += (t - yd.last_cycle_count);
	yd.last_cycle_count = t;
	
	// handle soft IRQs
	if (!yd.in_yield) {
		uint32_t gpio_edge, gpio, vga, x;
		
		yd.in_yield = 1;
		
		// detect changes in GPIO
		gpio        = GPIO_DATA;
		gpio_edge   = gpio ^ yd.last_gpio_read;
		
		// detect change in VGA
		vga         = VGA_CTRL;
		
		for (x = 0; x < MAX_IRQ; x++) {
			switch(irqs[x].type) {
				case YIELD_IRQ_INACTIVE: continue;
				case YIELD_IRQ_GPIO_LEVEL_HIGH:
					if (gpio & irqs[x].data) {
						irqs[x].handler(gpio);
					}
					break;
				case YIELD_IRQ_GPIO_LEVEL_LOW:
					if (~gpio & irqs[x].data) {
						irqs[x].handler(gpio);
					}
					break;
				case YIELD_IRQ_GPIO_POSEDGE:
					if (gpio_edge & gpio & irqs[x].data) {
						irqs[x].handler(gpio);
					}
					break;
				case YIELD_IRQ_GPIO_NEGEDGE:
					if (gpio_edge & ~gpio & irqs[x].data) {
						irqs[x].handler(gpio);
					}
					break;
				case YIELD_IRQ_UART_RX_READY:
					if (UART_STATUS & UART_STATUS_RX_READY) {
						irqs[x].handler(0);
					}
					break;
				case YIELD_IRQ_TIMER:
					if (yield_cycles > irqs[x].data2) {
						irqs[x].handler(0);
						irqs[x].data2 = yield_cycles + irqs[x].data;
					}
					break;
				case YIELD_IRQ_VBLANK:
					if (!(yd.last_vga_read & VGA_CTRL_VBLANK) && (vga & VGA_CTRL_VBLANK)) {
						irqs[x].handler(0);
					}
					break;
				case YIELD_IRQ_HBLANK:
					if (!(yd.last_vga_read & VGA_CTRL_HBLANK) && (vga & VGA_CTRL_HBLANK)) {
						irqs[x].handler(0);
					}
					break;
			}
		}
		yd.last_gpio_read = gpio;
		yd.last_vga_read  = vga;
		yd.in_yield       = 0;
	}		
}

void delay_ms(uint32_t ms)
{
	uint64_t tgt;
	yield();
	tgt = yield_cycles + ms * yd.cycles_per_msec;
	while (tgt > yield_cycles) {
		yield();
	}
}

void delay_usec(uint32_t usec)
{
	uint64_t tgt;
	yield();
	tgt = yield_cycles + usec * yd.cycles_per_usec;
	while (tgt > yield_cycles) {
		yield();
	}
}

int yield_add_irq(enum yield_irq_type type, uint64_t data, irq_handler_t handler)
{
	uint32_t x;
	for (x = 0; x < MAX_IRQ; x++) {
		if (irqs[x].type == YIELD_IRQ_INACTIVE) {
			irqs[x].type    = type;
			irqs[x].data    = data;
			irqs[x].handler = handler;
			if (type == YIELD_IRQ_TIMER) {
				irqs[x].data2 = yield_cycles + data;
			}
			return 0;
		}
	}
	return -1;
}

void yield_del_irq(irq_handler_t handler)
{
	uint32_t x;
	for (x = 0; x < MAX_IRQ; x++) {
		if (irqs[x].handler == handler) {
			irqs[x].type = YIELD_IRQ_INACTIVE;
		}
	}
}
