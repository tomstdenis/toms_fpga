# Simple QUAD SPI SRAM/PSRAM Flat Controller

This module implements a depth-1 narrow-to-wide BUS interface to the SRAM/PSRAM memory.
When instantiated for a 32-bit bus the byte enables are available which allows for simple
albeit high latency interface to mass memory.  When instantiated as a wider bus the
byte enables are ignored.

```
module spi_sram_flat #(
	parameter CLK_FREQ_MHZ=27,								// system clock frequency (required for walltime requirements)
	parameter DATA_WIDTH=32,								// controls the line size

	// default configuration for a 23LC512 (20MHz max QPI rate)
	parameter SRAM_ADDR_WIDTH=16,							// how many bits does the address have (e.g. 16 or 24)
	parameter DUMMY_BYTES=1,								// how many dummy reads are required before the first byte is valid
	parameter CMD_READ=8'h03,								// command to read 
	parameter CMD_WRITE=8'h02,								// command to write
	parameter CMD_EQIO=8'h38,								// command to enter quad IO mode
	parameter MIN_CPH_NS=5,									// how many ns must CS be high between commands (23LC's have a min time of mostly nothing)
	parameter SPI_TIMER_BITS=4,								// divide clock by 16 for SPI operations
	parameter QPI_TIMER_BITS=1								// divide clcok by 2 for QPI operations
)(
	input clk,												// clock
	input rst_n,											// active low reset

	// BUS
	output done,											// active high means the module is done with a request
	
	// DATA in/out
	input [DATA_WIDTH-1:0] data_in,							// data to write to the SRAM
	input data_in_valid,									// active high indicates the user wants to send data to the outgoing FIFO
	output reg [DATA_WIDTH-1:0] data_out,					// The entire line output
	input [3:0] data_be,									// byte enables (only supported for DATA_WIDTH==32)
	
	// CMD
	input write_cmd,										// active high we're doing a write
	input read_cmd,											// active high we're doing a read
	input [SRAM_ADDR_WIDTH-1:0] address,					// address to read/write from

	// I/O
	inout [3:0] sio_pin,									// data pins
	output cs_pin,											// active low CS pin
	output reg sck_pin										// SPI clock
);
```

# Theory of Operation
## Writing Memory

Set the following

- **data_in** to the data  to write
- **data_in_valid** to tell the module the data can be latched
- **data_be** to the byte enable you need
- **address** to the address
- **write_cmd** to 1

Next Cycle

- **write_cmd** to 0
- Wait for **done**==1

## Reading memory

- **data_be** to the byte enable you need
- **address** to the address
- **read_cmd** to 1
	
Next Cycle:

- **read_cmd** to 0
- wait for **done**==1
	
Later:
- read **data_out**

