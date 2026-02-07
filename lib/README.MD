Tom's Verilog Soft/Hard IP Library

This directory has various soft and harp IP wrappers for various things.  The organization is ${ip}/ for the bus wrapper, and ${ip}/blocks is for
the lower level blocks that are made up of it.

Bus Protocol
------------

The mem wrappers use a simple slave bus with the following common interface

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
 
Where clocking is on the posedge of clk, rst_n is active low (all other signals are active high).

A bus transaction is as follows

	- Cycle 1
		- set enable <= 1
		- set be <= 4'b1111, 4'b0011, or 4'b0001
		- set wr_en <= 1 if writing, 0 otherwise
		- set addr <= the address you're writing to, must be naturally aligned for the data width
		- set i_data <= data if writing
	- Cycle 2...N-1
		- Wait for ready=1
		- de-assert enable
		- o_data will contain data if reading.
	- Cycle N
		- One cycle with enable de_asserted.
		
If there is a bus error then bus_err and ready will be asserted at the same time.  Cleared by
deasserting enable.

If there is an IRQ then the irq pin should be active high.  We use the pending interrupt with write-1-clear
setup (similar to what most microcontrollers use).

The bus uses the lower 8 or 16 bits of i_data and o_data when be is 4'b0001 or 4'b0011 respectively.   Even if writing
to a non-zero (mod alignment) offset.

Modules
-------

	- timer: Simple counter with prescaler, and compare/top matching, pwm signal out, counter out
	- uart: FIFO based 8N1 UART
	- bsram: Wrapper creating 32KiB 8/16/32-bit memory usable on GW2A devices.
