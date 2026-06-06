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
  
- **math**: Various math things
  - **serial_divide**: Implements a simple shift/reduce division algorithm, produces quotient/remainder
  - **sqrt**: FPGA friendly simple O(ln(N)) integer square root (uses a DSP block).

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

- **spidma**: SPI DMA controller for PSRAM/SRAM (and eventually NOR flash) memories
   - Works with PSRAM/SRAM evices in SPI and QPI mode (using read, fast read, or quad read)
   - Run time management allows switching between QPI/SPI mode, more robust FSM that to handle diff technologies
   - Can DMA 1 .. 256 bytes from/to SPI memory to a host synchronous memory (registered or not)
   - Uses simple valid/ready handshake
   - Supports NOR commands (untested so far) for
     - sector erase
     - page program (which is really just "write" with a WEL and WIP loop)
     - read (same as SRAM)
     
- **spisddma**: SD SPI DMA controller for working with SDSC, SDHC, and SDXC cards
   - Tested with SDHC and SDXC cards
   - FSM inits the cards fetching CSD and CID info
   - Supports single sector read/write with SEND_STATUS return codes
   - Uses synchronous memory interface to host memory

- (deprecated) **sram**: SPI PSRAM/SRAM controllers
  - Works with PSRAM and SRAM devices in Quad-IO mode

- **cflea**: An implementation of Dave Dunfield's C-FLEA 16-bit VM in RTL
  - Implements full ISA including divide, mult, and switch
  - Really simple boot rom that can load Motorola S-Records
  - ALU ops take 8 cycles with bypass BRAM (12 if the operand is in memory)
  - Two added opcodes for getting top/core version and another to get lower 16 bits of cycle counter.
  - Top demo for Primer25K that is compatible with his Micro-C LIBCF runtime
     - Also sports a uart, timer, and VGA output
     - Hits ~125MHz with the barrel shifter

- **ib16**: An IttyBitty DIY **8-bit RISC** like processor with a 16-bit bus
  - Can be implemented fully on a Gowin GW1NZ-1 device (1152 LUT4, 850 DFF)
  - Uses simple bus controller logic that allows flexibility in how to service memory requests
  - 16 general purpose registers with shadow bank for interrupt handling (no need to push/pop in your ISR)
  - Has 2 and 3-operand ALU opcodes (reduces the need for manually moving register contents)
  - Any pair of registers can be used to access memory by combining to form a 16-bit address (other than r15+r15 which is used for stack operations)
  - RAM based stack (256 bytes default, configurable)
  - Supports **64KB address space**
  - Assembler provided with initial library code to write apps in
  - boot roms and demo programs for both a **nano1k** and **ECP5**/**Primer25K** demo designs

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
