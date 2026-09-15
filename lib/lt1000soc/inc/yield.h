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
	YIELD_IRQ_VBLANK,
	YIELD_IRQ_HBLANK,
};

// 64-bit count of cycles since yield_init()
extern uint64_t yield_cycles;

// initialize yield library
void yield_init(void);

// call this to yield to timer and soft IRQs
void yield(void);

// delay milliseconds
void delay_ms(uint32_t ms);

// delay microseconds
void delay_usec(uint32_t usec);

// insert a new IRQ (-1 == error)
int yield_add_irq(enum yield_irq_type type, uint64_t data, irq_handler_t handler);

// remove any IRQ that has this as a handler
void yield_del_irq(irq_handler_t handler);

// returns the # of cycles per microsecond
uint64_t yield_usec_to_cycles(void);

#endif
