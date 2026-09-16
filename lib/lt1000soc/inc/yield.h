#ifndef LT1000_YIELD_H
#define LT1000_YIELD_H

#define MAX_IRQ 8

typedef void (*irq_handler_t)(uint32_t event_flags);

enum yield_irq_type {
	YIELD_IRQ_INACTIVE=0,      // IRQ is not used
							   // GPIO uses "data" as a bitmask and
							   // passed as the current GPIO data in the handler
	YIELD_IRQ_GPIO_LEVEL_HIGH, // trigger on any selected GPIO is high
	YIELD_IRQ_GPIO_LEVEL_LOW,  // trigger on any selected GPIO is low
	YIELD_IRQ_GPIO_POSEDGE,    // trigger on any selected GPIO positive edge
	YIELD_IRQ_GPIO_NEGEDGE,    // trigger on any selected GPIO negedge 
	YIELD_IRQ_UART_RX_READY,   // triggers as long as RX READY is high
	YIELD_IRQ_TIMER,           // data is the # of clock cycles per event
	YIELD_IRQ_VBLANK,          // triggers on posedge of vertical blank
	YIELD_IRQ_HBLANK,          // triggers on posedge of horizontal blank
	YIELD_IRQ_ALWAYS,		   // triggers every time yield() is called (any for arbitrary logic in delay_*() calls)
	YIELD_IRQ_MEMEQ,           // triggers when mem[data] == data2
	YIELD_IRQ_MEMAND,		   // triggers when mem[data] & data2
};

// 64-bit count of cycles since yield_init()
extern uint64_t yield_cycles;

// initialize yield library
void yield_init(void);

// call this to yield to timer and soft IRQs (must call at least once every 42 seconds (@100MHz)... ideally sooner)
void yield(void);

// delay milliseconds
void delay_ms(uint32_t ms);

// delay microseconds
void delay_usec(uint32_t usec);

// insert a new IRQ (-1 == error)
int yield_add_irq(enum yield_irq_type type, uint64_t data, uint64_t data2, irq_handler_t handler);

// remove any IRQ that has this as a handler
void yield_del_irq(irq_handler_t handler);

// returns the # of cycles per microsecond
uint64_t yield_usec_to_cycles(void);

// disable IRQs (for when you still want timing but not IRQs)
void yield_cli(void);

// enable IRQs
void yield_sei(void);

#endif
