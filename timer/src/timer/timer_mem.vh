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