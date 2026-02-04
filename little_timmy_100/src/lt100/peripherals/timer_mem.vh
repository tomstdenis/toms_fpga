/* This is a "bus" wrapper around the timer block

The following registers are mapped to the following addresses

`define TIMER_TOP_L_ADDR        (32'h0000)        // lower 8-bits of TOP value
`define TIMER_TOP_H_ADDR        (32'h0004)        // upper 8-bits of TOP value
`define TIMER_CMP_L_ADDR        (32'h0008)        // lower 8-bits of compare 
`define TIMER_CMP_H_ADDR        (32'h000C)        // upper 8-bits  of compare
`define TIMER_PRESCALE_ADDR     (32'h0010)        // 8-bit prescaler
`define TIMER_INT_ENABLE_ADDR   (32'h0014)        // interrupt enable bits ([0] == TOP, [1] == CMP)
`define TIMER_INT_PENDING_ADDR  (32'h0018)        // interrupt pending bits ([0] == TOP, [1] == CMP)
`define TIMER_ENABLE_ADDR       (32'h001C)        // timer enable ([0] == go)
`define TIMER_COUNTER_L_ADDR    (32'h0020)        // lower 8 bits of counter (must read first)
`define TIMER_COUNTER_H_ADDR    (32'h0024)        // upper 8 bits of counter (read second)

The timer works by counting from 0 to TOP and then resets.  It emits three signals

    - top_match: when counter == top
    - compare match: when counter == compare
    - pwm: when counter <= compare
    - irq: when there is a pending interrupt matched by an interrupt enable.

You can read/write the L address of 16-bit fields using a 16 or 32-bit access to read the full field.
e.g. a 16-bit read from 0000 is the same as a byte read from 0000 and 0004.

The interrupt registers use the lsb to indicate a TOP match and the next bit for a compare match.  The pending
registers is write-1-clear (W1C) meaning you can clear the pending flag by writing a 1 to the corresponding register.

You must write a '1' bit to the lsb of TIMER_ENABLE_ADDR to turn the timer on (0 turns it off).

You can read the current counter value by reading TIMER_COUNTER_X (or 16/32-bit read from the L part)

*/

`ifndef TIMER_MEM_VH
`define TIMER_MEM_VH

`define TIMER_INT_TOP_MATCH 0
`define TIMER_INT_CMP_MATCH 1

`define TIMER_TOP_L_ADDR        (32'h0000)        // lower 8-bits of TOP value
`define TIMER_TOP_H_ADDR        (32'h0004)        // upper 8-bits of TOP value
`define TIMER_CMP_L_ADDR        (32'h0008)        // lower 8-bits of compare 
`define TIMER_CMP_H_ADDR        (32'h000C)        // upper 8-bits  of compare
`define TIMER_PRESCALE_ADDR     (32'h0010)        // 8-bit prescaler
`define TIMER_INT_ENABLE_ADDR   (32'h0014)        // interrupt enable bits ([0] == TOP, [1] == CMP)
`define TIMER_INT_PENDING_ADDR  (32'h0018)        // interrupt pending bits ([0] == TOP, [1] == CMP)
`define TIMER_ENABLE_ADDR       (32'h001C)        // timer enable ([0] == go)
`define TIMER_COUNTER_L_ADDR    (32'h0020)        // lower 8 bits of counter (must read first)
`define TIMER_COUNTER_H_ADDR    (32'h0024)        // upper 8 bits of counter (read second)

`endif