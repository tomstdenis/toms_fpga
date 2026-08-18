# Nano (P)SRAM Driver

This Verilog module presents a simple 1-byte-wide interface to SPI-based 8-pin (P)SRAM chips that support QPI mode. It provides an interface to start a read or write transaction, which is then prompted by strobe signals and continued until the transmission signal is lowered. This provides a rather compact module to stream data with.

Note: In PSRAM mode it uses a 50nS hangup timer and a 50uS wakeup timer.

## Instantiation

The module has five parameters that configure it for the particular SRAM IC you are using and the clock domain your module will reside in:

1. **SRAM_ADDR_WIDTH**: The number of bits in the address, typically 24 or 16. Default: 24.
2. **DUMMY_BYTES**: Number of dummy bytes to read when performing an `8'h0B` fast read. Default: 3.
3. **QPI_TIMER**: Length of each half-phase of SCK, expressed as: **1 + QPI_TIMER**. Default: 0.
4. **PSRAM**: Enable PSRAM mode (0 == SRAM mode). Default: 0
5. **FREQ**: Frequency in MHz (only used in PSRAM mode). Default: 81

The module has the following ports:

```verilog
    input wire clk,                            // Core clock signal
    input wire rst_n,                          // Active low reset
    
    // command 
    input wire [SRAM_ADDR_WIDTH-1:0] addr,     // address to access in SRAM
    input wire [7:0]                 data_in,  // byte to write to SRAM
    input wire                       wr_en,    // write enable control (cannot be swapped during a transaction)
    output reg [7:0]                 data_out, // byte read from SRAM
    
    // control
    input wire  start_trans,                   // start a transaction (hold high during the entire transmission)
    output wire busy,                          // busy sending/receiving 
    output wire idle,                          // we're in the idle state waiting to start_trans
    output reg  ready,                         // we're done sending the command; you should respond to strobes now
    output reg  read_strobe,                   // high when you can read data_out (lasts one cycle)
    output reg  write_strobe,                  // high when you should either send a new data_in or take start_trans low to stop further writes

    // I/O
    input wire [3:0] sio_din,                  // QPI data in
    output reg [3:0] sio_dout,                 // QPI data out
    output reg       sio_en,                   // QPI output enable (1 == output, 0 == input)
    output reg       cs_pin,                   // active low CS pin
    output reg       sck_pin                   // SPI clock

```

## Reset

Upon raising **rst_n** high, the module enters an initialization sequence where, in SPI mode, it transmits the command `8'h38`, which is the typical "enter Quad IO" mode command. Initialization finishes with the **idle** signal going high.

## Write Timing

Timing is in terms of the three parameters chosen when instantiating the module. A byte takes **X** = 4 * (**QPI_TIMER** + 1) cycles to transfer over the QPI bus. Each command is 1 byte, followed by the 2- or 3-byte address, and for reads, followed by dummy bytes.

From the start of a transmission to the first byte being written takes:

```
FW = 2 + (SRAM_ADDR_WIDTH/8) + X * (1 + SRAM_ADDR_WIDTH/8) + X
```

cycles to complete the first byte. The `2 + (SRAM_ADDR_WIDTH/8)` term comes from the three FSM transitions to get into the bulk transfer FSM state. The **write_strobe** signal is signaled on the first cycle of the SCK low phase and then every **X** cycles after that. The first write strobe occurs at:

```
FWS = 2 + (SRAM_ADDR_WIDTH/8) + X * (1 + (SRAM_ADDR_WIDTH/8)) + (X/2)
```

The write strobe happens after the first nibble is transmitted and then every **X** cycles after that.

For the default configuration:

```
FW  = 2 + 3 + 4 * (1 + 3) + 4
    = 2 + 3 + 4 * 4 + 4
    = 25

FWS = 2 + 3 + 4 * (1 + 3) + 2
    = 5 + 4 * 4 + 2
    = 23
```

This means that in the default configuration, the first byte is written in 25 cycles and the first write strobe happens in 23 cycles. A new write strobe happens every 4 cycles and a new byte is written every 4 cycles.

## Read Timing

Read timing is similar, except there are **DUMMY_BYTES** to contend with. The first byte is read and the read strobe is signaled (these are the same event) after:

```
FR = 2 + (SRAM_ADDR_WIDTH/8) + DUMMY_BYTES + X * (1 + (SRAM_ADDR_WIDTH/8) + DUMMY_BYTES) + X
```

cycles, after which a new byte is read (and strobe signaled) every **X** cycles.

For the default configuration:

```
FR = 2 + 3 + 3 + 4 * (1 + 3 + 3) + 4
   = 8 + 4 * 7 + 4
   = 40
```

This means the first byte takes 40 cycles to be read, and a new byte is available every 4 cycles after that.

## Theory of Operation: Reading

To read memory, first wait for **idle** to go high, then drive the following nets:

* **addr**: The byte address to read
* **start_trans**: 1
* **wr_en**: 0

The cycle after this, you can wait for **read_strobe** to go high, at which point you can read **data_out**. If you lower **start_trans** on the 2nd to last byte, the FSM will stop after reading the next byte.

If you want to only read 1 byte, you need to lower **start_trans** on the cycle after you raise it.

As RTL pseudo-code:

```verilog
   // wait for idle
   while (!idle);

   // program job
   addr <= read_address; wr_en <= 0; start_trans <= 1; cnt <= 0;
   
   // transfer bytes
   while (cnt != bytes_to_read) {              // read 'bytes_to_read' bytes into buffer[]
    if (read_strobe) {                         // wait for ready and read strobe
        if (cnt == bytes_to_read - 1) {        // if we're on the last or 2nd last byte stop shifting after the next byte
            start_trans <= 0;
        }
        buffer[cnt++] <= data_out;             // store the byte
    }
   }
```

## Theory of Operation: Writing

To write memory, first wait for **idle** to go high, then drive the following nets:

* **addr**: The byte address to start writing to
* **start_trans**: 1
* **wr_en**: 1
* **data_in**: The first byte to write

The cycle after this, you can wait for **write_strobe** to go high, at which point you can either drive another byte in **data_in** or lower **start_trans** to stop writing.

As RTL pseudo-code:

```verilog
   // wait for idle 
   while (!idle);

   // program job
   addr <= write_address; wr_en <= 1; start_trans <= 1; data_in <= buffer[0];

   // transfer bytes
   cnt <= 0;
   while (cnt != bytes_to_write) {             // write 'bytes_to_write' bytes from buffer[]
    if (write_strobe) {                        // wait for ready and write strobe
        if (cnt == bytes_to_write - 1) {       // if we're on the last or 2nd last byte stop shifting after the next byte
            start_trans <= 0;
        } else {
            data_in <= buffer[++cnt];
        }
    }
   }
```

## Caveats

* When actively reading or writing, make sure to check if **ready** is high as well. The **read_strobe** and **write_strobe** signals will fire during command, address, or initialization sequencing.
* With most SRAMs, you can keep a transmission alive indefinitely. Due to the nature of this module, that means you're constantly reading or writing as long as **start_trans** is high.
* There must be one cycle in which **start_trans** is low between jobs, and you must wait for **idle** to be high before changing any of the command parameters, including setting **start_trans** back to high.
* The included testbench **nanosram_tb.v** demonstrates how to perform a 16-byte-long burst.
* In PSRAM mode keep in mind there's a hangup delay between transmissions and you can only hold **start_trans** high for around 4uS at a max (depends on PSRAM).
