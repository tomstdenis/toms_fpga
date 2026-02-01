/* This is a "bus" wrapper around the uart block

Provides for the following addresses (uses a 3-bit address width)

    localparam
        UART_BAUD_L_ADDR      = 3'b000,   <--- (reset: 0) lower 8 bits of baud divisor
        UART_BAUD_H_ADDR      = 3'b001,   <--- (reset: 0) upper 8 bits of baud divisor (combined BAUD = F_CLK/bauddiv[15:0])
        UART_STATUS_ADDR      = 3'b010,   <--- STATUS register (bit 0 == RX ready, bit 1 == TX fifo full)
        UART_DATA_ADDR        = 3'b011,   <--- 8-bit data register 
        UART_INT_ADDR         = 3'b100,   <--- (reset: 0) Interrupt enables (bit 0 == RX_READY, bit 1 == TX fifo empty)
        UART_INT_PENDING_ADDR = 3'b101;   <--- (reset: 0) Interrupt pending flags (bit 0 == RX_READY, bit 1 == TX fifo empty)

    Each address can be written or read.  Writing to STATUS does nothing.

    Writing a 1 to a bit of INT_ADDR enables a particular interrupt.  Writing a '1' to a bit of INT_PENDING clears the pending interrupt.
Both use this layout for interrupt bits.

    localparam
        UART_INT_RX_READY     = 0,        <--- Interrupt as soon as a byte is available to read
        UART_INT_TX_EMPTY     = 1;        <--- Interrupt once the TX fifo empties completely.

    The core operates by setting your wr_en, addr, i_data (if !wr_en).  Then issue enable=1 for as many cycles as it takes for ready to go high,
then deassert enable for 1 cycle before the next command.

*/

`ifndef uart_mem_vh
`define uart_mem_vh

// addresses for various registers inside the block
`define UART_BAUD_L_ADDR      32'h0000
`define UART_BAUD_H_ADDR      32'h0004
`define UART_STATUS_ADDR      32'h0008
`define UART_DATA_ADDR        32'h000C
`define UART_INT_ADDR         32'h0010
`define UART_INT_PENDING_ADDR 32'h0014

// bit positions of the pending and enable interrupts
`define UART_INT_RX_READY     0
`define UART_INT_TX_EMPTY     1

`endif