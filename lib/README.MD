# Tom's Verilog Soft/Hard IP Library

This directory has various soft and harp IP wrappers for various things.  The organization is ${ip}/ for the bus wrapper, and \${ip}/blocks is for
the lower level blocks that are made up of it.

Bus Protocol
------------

The mem wrappers use a simple slave bus with the following common interface

```
module slave_device
#(
    parameter ADDR_WIDTH=32,
    parameter DATA_WIDTH=32,
    WIDTH=8192                  // using four 8bits x WIDTH long arrays
)(
    // common bus in
    input clk,
    input rst_n,            // active low reset
    input enable,           // active high overall enable (must go low between commands)
    input wr_en,            // active high write enable (0==read, 1==write)
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] i_data,
    input [DATA_WIDTH/8-1:0] be,       // lane 0 must be asserted, other lanes can be asserted but they're ignored.

    // common bus out
    output reg ready,       // active high signal when o_data is ready (or write is done)
    output reg [DATA_WIDTH-1:0] o_data,
    output wire irq,        // active high IRQ pin
    output wire bus_err    // active high error signal

    // peripheral specific
);
```

Where clocking is on the posedge of clk, rst_n is active low (all other signals are active high).

A single bus transaction is as follows

    - Cycle 0:    enable = 0, (meaning ready/err are 0 too)
    - Cycle 1:    enable = 1, set addr/be/wr_en and i_data if wr_en
    - Cycle N >= 2: ready = 1, command complete o_data is valid (if !wr_en)
    - Go back to cycle 0

A burst read or write (ONLY FOR peripherals that support it which isn't all of them) is similiar

    - Cycle 0: enable <= 0
    - Cycle 1: enable <= 1, set addr/be/wr_en
    - Cycle N >= 2: ready goes high, read or write next byte/half/word depending on wr_en
    - Cycle ..M-1: Hold enable high as you read/write more symbols
        - Go back to cycle 0.

As long as enable is held high the peripheral will seek to the next address.  Again only for peripherals that support it.  If a peripheral overflows/underruns it may deassert ready at which point the transaction is concluded.

If there is a bus error then bus_err and ready will be asserted at the same time.  Cleared by deasserting enable.

If there is an IRQ then the irq pin should be active high.  We use the pending interrupt with write-1-clear setup (similar to what most microcontrollers use).

The bus uses the lower 8 or 16 bits of i_data and o_data when be is 4'b0001 or 4'b0011 respectively.   Even if writing to a non-zero (mod alignment) offset.

Modules
-------

- **debug**: A chainable debug system that allows reading and writing 128-bit payloads deep inside design, supports dynamic addressing with identifiable nodes.

- **fifo**: A generic read/write single clock FIFO with flush support
  
  - Implemented in **fifo/fifo.v** with test bench **fifo/fifo_tb.v**.

- **uart**: A 8N1 serial UART with FIFO support.
  
  - Individual transmit and receive implemented as
    
    - Transmit: **uart/blocks/tx_uart.v** with test bench **uart/blocks/tx_uart_tb.v**
    
    - Receive: **uart/blocks/rx_uart.v** with test bench **uart/blocks/rx_uart_tb.v**
    
    - Transceiver (with FIFO): **uart/blocks/uart.v** with test bench **uart/blocks/uart_tb.v**
      
      - Has parameters for FIFO depth, RX and TX enables.
  
  - A bus wrapper in **uart/uart_mem.v** with test bench **uart/uart_mem_tb.v**
    
    - Supports IRQ for TX and RX using W1C clears

- **timer**: A generic timer with variable width prescaler and counter.  Provides signals for compare match, top match, and PWM signalling.
  
  - Low level timer imlemented in **timer/blocks/timer.v** with test bench **timer/blocks/timer_tb.v**
  
  - A bus wrapper in **timer/timer_mem.v** with test bench **timer/timer_mem_tb.v**

- **bsram**: On GW2AR parts the Block SRAM doesn't support a byte enable so this wrapper provides it.  Also allows **burst** mode traffic on the bus protocol.
  
  - Implemented in **bsram/sp_bsram.v** with test bench **bsram/sp_bsram_tb.v**
  
  - Default configuration is for 32KB (out of 92KB) in four 8x8192 memories.  (Uses 16 out of 46 BRAM blocks)
  
  - Implements byte lanes supporting naturally aligned byte, word, dword reads and writes (bus_err on unaligned access).

- **useq**: A DIY 8-bit processor using 4KB of block ram as the main memory
  
  - Uses about 1400 logic cells (7% of GW2AR-18), 5 SRAM blocks, 2 DPB blocks, 1 MULT9x9 in the demo configuration.
  
  - Core provides bit-twiddling efficient opcodes
  
  - Supports a HW accelerated FIFO that the parent module can also steer data into and out of for the core to work with
  
  - Supports a HW stack
  
  - Has IRQ support
  
  - Has parameters to enable/disable IRQs, Host FIFO control, and you can control the size of the FIFO and the Stack.
  
  - Supports 8 input and 8 output ports (or you can overlay them 8574 style)
  
  - Operates at 3 cycles per opcode and can PNR at around 80-94.5MHz more than fast enough to bit bang many simple protocols (spi/i2c/uart).  A 60MHz clock would roughly approximate an AVR core's performance.
  
  - Comes with a bootloader to load applications and assembler.
