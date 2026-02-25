# Simple Quad SPI SRAM/PSRAM controller

This directory has a portable quad rate SPI SRAM/PSRAM which issues a SPI
command to enter quad-io mode and then issues standard READ and WRITE commands
via a FIFO mechanism.  It's mostly meant as a backfill for a cache controller 
but can be used as a bus slave to read 1, 2, 4 byte words at any offset.

The module has a variety of parameters.  The FIFO depth can be tuned
to match your cache line.  It defaults to 32.  The SRAM address width
can be either 16 bits or 24 bits.  If your chip uses fewer bits but still
needs 16 or 24 bits use those sizes.  The amount of read dummy bytes
can be set with DUMMY_BYTES and will vary between SRAM and PSRAM and various
clock rates.  23LC's for instance need 1 dummy read, whereas PSRAMS
can need 6 or more.

The module also has a programmable hangup timer since PSRAMs need a certain
minimum period between CS lows.  For 23LC's it can be trivially low
for PSRAMS it's typically 50ns at least.

Finally the data rate can be specified the SPI_TIMER_BITS and QPI_TIMER_BITS is how many
log2 divisions of input clock.  For instance a SPI_TIMER_BITS of 4 divides the input
clock by 16.  The only thing SPI is used for is entering QPI mode.  Keep in mind
most ICs have a lower clockrate for SPI commands.  The QPI_TIMER_BITS should be chosen
to stay around ~100MHz (or less depending on temp, voltage, and wire length).

To **write** to SPI SRAM you first have to feed the FIFO this is done by

1. Hold data_in_valid high, assert data byte to store in data_in

2. When done take data_in_valid low, assert the address and then write_cmd high

3. Wait for done to go high

To **read** from SPI SRAM you:

1. Assert the address, read_cmd_size (# of bytes to read), and read_cmd
   
2. Wait until done goes high

3. Until data_out_empty:
  3.1 Store data_out [it's preloaded by time done is asserted]
  3.2 Take data_out_read high
      
4. Take data_out_read low

The module controls a single SPI chip and requires external pullups on 
cs_pin and sio_pin[3:0] (which has to be tristate capable) and a pulldown
on sck_pin.  If you re-route the CS pin via a mux you can control more than
one SPI (P)SRAM chip (of the same design) from a single instantation of
the module. 

```
module spi_sram #(
    parameter CLK_FREQ_MHZ=27,                              // system clock frequency (required for walltime requirements)
    parameter FIFO_DEPTH=32,                                // controls the max burst size
    parameter SRAM_ADDR_WIDTH=16,                           // how many bits does the address have (e.g. 16 or 24)
    parameter DUMMY_BYTES=1,                                // how many dummy reads are required before the first byte is valid
    parameter CMD_READ=8'h03,                               // command to read 
    parameter CMD_WRITE=8'h02,                              // command to write
    parameter CMD_EQIO=8'h38,                               // command to enter quad IO mode
    parameter MIN_CPH_NS=5,                                 // how many ns must CS be high between commands (23LC's have a min time of mostly nothing)
    parameter SPI_TIMER_BITS=4,                             // divide clock by 16 for SPI operations
    parameter QPI_TIMER_BITS=1                              // divide clcok by 2 for QPI operations
)(
    input clk,                                              // clock
    input rst_n,                                            // active low reset

    output done,                                            // active high means the module is done with a request

    input [7:0] data_in,                                    // data we want to write to the core
    input data_in_valid,                                    // active high indicates the user wants to send data to the outgoing FIFO
    output [7:0] data_out,                                  // assigned fifo[read_ptr]
    input data_out_read,                                    // active high indicates read_ptr should be incremented
    output data_out_empty,                                  // active high when all data read from the SPI SRAM is read from the fifo

    input write_cmd,                                        // active high we're doing a write
    input read_cmd,                                         // active high we're doing a read
    input [$clog2(FIFO_DEPTH):0] read_cmd_size,             // how many bytes the user wants to read
    input [23:0] address,                                   // address to read/write from

    inout [3:0] sio_pin,                                    // data pins
    output cs_pin,                                          // active low CS pin
    output sck_pin                                          // SPI clock
);
```
