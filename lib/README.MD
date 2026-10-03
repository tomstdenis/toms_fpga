# Tom's Verilog Soft IP Library

This directory has various soft IP wrappers for various things.  

Modules
-------

- **nanofpu**: A mostly IEEE compliant round-to-zero 32-bit float module that supports add, sub, mult, divide, sqrt, load int, store int, and some parallel integer operations.
  - Each function is a stand alone module you can just use as is.
  - Most functions have parameters to allow area/timing tradeoffs
  - **nanofpu/nanofpu.v** provides a simple module wrapper around all of the individual FPU blocks with parameters to allow you to disable functions you don't need to save area/timing.
  - **nanofpu/nanovex.v** for when one FPU isn't enough.  This prototype module chains 7 FPUs into a 4:2:1 reduction tree that can do things like a vector dot product as an "atomic" function, etc.
     - Each FPU in the **nanovex** can customize which functions it supports
     - All FPUs share the same optimization settings though.

- **nanosram**: SPI PSRAM/SRAM controller that is optimized for low area.  Provides streaming memory access with read and write strobes.
  - Module in **nanosram/nanosram.v** with test bench **nanosram/nanosram_tb.v**
  - Readme in **nanosram/README.MD**

- **nanocache**: A direct mapped cache that wraps around **nanosram**.  Comes in three configurations for various tech/area spends.  Provides a 32-bit interface with write enables per lane.
  - The basic module **nanocache/nanocache.v** can work with a single BRAM block in either SDP or DP modes, in bypass or registered mode.  It's the most basic form useful for deploying on older FPGA or libraries.
  - A combinatorial module **nanocache/nanocache_comb.v** only works with dual ported and registered BRAMs.  This version combinatorially starts access which shaves a cycle off cache hits.
  - A 32-bit combinatorial module **nanocache/nanocache_comb_32bit.v** like the previous module except it uses four dual ported BRAM arrays to provide a full 32-bit write or read hit in one cycle.

- **vga**: An "all in one" 320x200x8bpp and 80x50 VGA driver, supports a pair of 64KB video pages with hardware page flipping.
   - Module in **vga/blocks/vga.v** (it includes **vga/blocks/8x8_font_256.hex** automatically)
   - Per default requires 128KB of BRAM
      - If you tie the page selector to a constant 1'b0 and wire the 17th host address bit to 1'b0 you can pair this down to 64KB
   - GFX mode supports 320x200 with a fixed 332 palette
   - Text mode supports 80x50 with colour bytes adjacent to text bytes
      - Colour format is IRGBirgb (foreground in [7:4], background in [3:0])
   - Provides the host a 32-bit interface (with byte enables) to the video frame buffer.
   - Does the full scanout generation exporting raw VGA red, green, blue, vsync, and hsync signals (also exports vblank and hblank signals for DVI TX generation)
   - Includes a CP437 8x8 font

- Legacy **vga**: A smaller 2KB or 4KB VRAM VGA module
   - Uses **vga/blocks/vga_timing.v** for timing signals
   - Uses **vga/blocks/vga_text_driver.v** for text symbol generation
   - Text mode supports 80x25 tested with 8 and 16 bits per symbol
      - Allows pure monochrome text or colour text.
   - Supports a "low res graphics" mode of 40x40
   - `Does not` actually do scanout generation (see my various vga demos) itself only generates timing and "next text symbol" generation

- **vt100**: A vt100 emulator that combines a serial input and the legacy VGA.
   - Module in **vt100/vt100.v**.
   - Relatively simple way to add a serial console to a project
   - Exports VGA scanout signals making it easy to wire up to a display
   - Only requires semi-dual-port memories so it's easy to port to low spec libraries or FPGAs
   - Imports **uart** and **legacy vga** blocks internally.
   - Tested on my Tang Nano 1K

- **spi**: A simple 8-bit SPI master transfer module that has variable SCK timing (counter divider).
   - Module in **spi/spi.v**

- **uart**: A 8N1 serial UART with FIFO support.
  - Individual transmit and receive implemented as
    - Transmit: **uart/blocks/tx_uart.v** with test bench **uart/blocks/tx_uart_tb.v**
    - Receive: **uart/blocks/rx_uart.v** with test bench **uart/blocks/rx_uart_tb.v**
    - Transceiver (with FIFO): **uart/blocks/uart.v** with test bench **uart/blocks/uart_tb.v**
      - Has parameters for FIFO depth, RX and TX enables.

- **spisddma**: SD SPI DMA controller for working with SDSC, SDHC, and SDXC cards
   - Tested with SDHC and SDXC cards
   - FSM inits the cards fetching CSD and CID info
   - Supports single sector read/write with SEND_STATUS return codes
   - Uses synchronous memory interface to host memory

- **lt1000soc**: A RISC-V IM32 (with DIY FPU) System on Chip
   - Implements IM32 instruction set with nanofpu mapped to some Custom-0 instructions
   - Supports 128KB VGA with 320x200 graphics and 80x50 text
   - Configurable (default: 64KB) Tightly Coupled Memory (TCM)
   - Configurable (default: 8KB) BIOS ROM
   - Uses **nanocache** to map a cached (default: 8KB cache) region of upto 16MiB region of PSRAM into the address map.
   - Peripherals
      - 32 independently configurable bidirectional GPIO inout lanes
      - 8N1 UART (locked to 1Mbit baud)
      - SPI master with four CS lanes
   - Comes with starter library, tested with a version of gcc+newlib I found on the net.
   - Requires YosysHQ's picorv32.v module (`not included`) to be placed in **lt1000soc/picorv32/**

## Older Modules  

These are older modules that are either not being actively developed or have been fully replaced with newer designs.  Kept here for historical reasons.

- **math**: Various integer math things
  - **serial_divide**: Implements a simple shift/reduce division algorithm, produces quotient/remainder
  - **sqrt**: FPGA friendly simple O(ln(N)) integer square root (uses a DSP block).

- **debug**: A chainable debug system that allows reading and writing payloads deep inside design, supports dynamic addressing with identifiable nodes.
  - Supports variable build time sized payloads.
  - Relatively simple to wire up
  - Supports CDC easily.

- **fifo**: A generic read/write single clock FIFO with flush support
  - Implemented in **fifo/fifo.v** with test bench **fifo/fifo_tb.v**.
  
- **timer**: A generic timer with variable width prescaler and counter.  Provides signals for compare match, top match, and PWM signalling.
  - Low level timer imlemented in **timer/blocks/timer.v** with test bench **timer/blocks/timer_tb.v**
  - A bus wrapper in **timer/timer_mem.v** with test bench **timer/timer_mem_tb.v**

- (`DEPRECATED`) **spidma**: SPI DMA controller for PSRAM/SRAM (and eventually NOR flash) memories
   - Works with PSRAM/SRAM evices in SPI and QPI mode (using read, fast read, or quad read)
   - Run time management allows switching between QPI/SPI mode, more robust FSM that to handle diff technologies
   - Can DMA 1 .. 256 bytes from/to SPI memory to a host synchronous memory (registered or not)
   - Uses simple valid/ready handshake
   - Supports NOR commands (untested so far) for
     - sector erase
     - page program (which is really just "write" with a WEL and WIP loop)
     - read (same as SRAM)

- (`DEPRECATED`) **sram**: SPI PSRAM/SRAM controllers
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
