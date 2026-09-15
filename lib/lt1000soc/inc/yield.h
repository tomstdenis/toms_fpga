#ifndef LT1000_YIELD_H
#define LT1000_YIELD_H

#define MAX_IRQ 8

typedef void (*irq_handler_t)(uint32_t event_flags);

enum yield_irq_type {
	YIELD_IRQ_INACTIVE=0,
	YIELD_IRQ_GPIO_LEVEL_HIGH,
	YIELD_IRQ_GPIO_LEVEL_LOW,
	YIELD_IRQ_GPIO_POSEDGE,
	YIELD_IRQ_GPIO_NEGEDGE,
	YIELD_IRQ_UART_RX_READY,
	YIELD_IRQ_TIMER,
};

extern uint64_t yield_cycles;

void yield_init(void);
void yield(void);
void delay_ms(uint32_t ms);
void delay_usec(uint32_t usec);
int yield_add_irq(enum yield_irq_type type, uint64_t data, irq_handler_t handler);
uint64_t yield_usec_to_cycles(void);

#endif
