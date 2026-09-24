#include "lt1000.h"

uint64_t yield_cycles = 0;

static struct {
	uint32_t
		cycles_per_usec,
		cycles_per_msec,
		last_cycle_count,
		last_gpio_read,
		last_vga_read;
	int
		irq_enabled,
		in_yield;
} yd;

static struct {
	enum yield_irq_type type;
	uint64_t       data, data2;
	void (*handler)(uint32_t data);
} irqs[MAX_IRQ];

void yield_init(void)
{
	uint32_t x;
	
	for (x = 0; x < MAX_IRQ; x++) {
		irqs[x].type = YIELD_IRQ_INACTIVE;
	}
	
	yd.cycles_per_usec  = MCFG_FREQ_MHZ(MCFG_DATA);
	yd.cycles_per_msec  = MCFG_FREQ_MHZ(MCFG_DATA) * 1000UL;
	yd.in_yield         = 0;
	yield_cycles        = 0;

	yd.last_gpio_read   = GPIO_DATA;
	yd.last_vga_read    = VGA_CTRL;
	yd.irq_enabled      = 0;
	yield_cycles        = yd.last_cycle_count = TIMER;
	
}

uint64_t yield_usec_to_cycles(void)
{
	if (!yield_cycles) {
		yield_init();
	}
	return yd.cycles_per_usec;
}

TCM_FUNC(yield) void yield(void)
{
	uint32_t t;
	
	if (!yield_cycles) {
		yield_init();
	}
	
	// handle soft IRQs
	if (yd.irq_enabled && !yd.in_yield) {
		uint32_t gpio_edge, gpio, vga, x;
		
		yd.in_yield = 1;
		
		// detect changes in GPIO
		gpio        = GPIO_DATA;
		gpio_edge   = gpio ^ yd.last_gpio_read;
		
		// detect change in VGA
		vga         = VGA_CTRL;
		
		for (x = 0; x < MAX_IRQ; x++) {
			// only force timer update on first pass 
			if (x && irqs[x].type == YIELD_IRQ_INACTIVE) {
				continue;
			}
			
			// update timer before each IRQ handler for more precise timing
			t = TIMER;
			yield_cycles += (t - yd.last_cycle_count);
			yd.last_cycle_count = t;

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
						irqs[x].data2 = yield_cycles + irqs[x].data;
						irqs[x].handler(0);
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
				case YIELD_IRQ_ALWAYS:
					irqs[x].handler(0);
					break;
				case YIELD_IRQ_MEMEQ:
				{
					uint32_t p = ((uint32_t *)(uint32_t)irqs[x].data)[0];
					if (p == irqs[x].data2) {
						irqs[x].handler(p);
					}
					break;
				}
				case YIELD_IRQ_MEMAND:
				{
					uint32_t p = ((uint32_t *)(uint32_t)irqs[x].data)[0];
					if (p & irqs[x].data2) {
						irqs[x].handler(p);
					}
					break;
				}
			}
		}
		yd.last_gpio_read = gpio;
		yd.last_vga_read  = vga;
		yd.in_yield       = 0;
	} else {	
		// update timer
		t = TIMER;
		yield_cycles += (t - yd.last_cycle_count);
		yd.last_cycle_count = t;
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

int yield_add_irq(enum yield_irq_type type, uint64_t data, uint64_t data2, irq_handler_t handler)
{
	uint32_t x;
	yield();
	for (x = 0; x < MAX_IRQ; x++) {
		if (irqs[x].type == YIELD_IRQ_INACTIVE) {
			irqs[x].type    = type;
			irqs[x].data    = data;
			irqs[x].data2   = data2;
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

void yield_cli(void)
{
	yield();
	yd.irq_enabled = 0;
}

void yield_sei(void)
{
	yield();
	yd.irq_enabled = 1;
}
