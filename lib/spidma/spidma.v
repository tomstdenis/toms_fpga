`timescale 1ns/1ps
`default_nettype none

`define spidma_cmd_read 4'h0
`define spidma_cmd_write 4'h1

module spidma #(
	// Timing
	parameter CLK_FREQ_MHZ=27,								// system clock frequency (required for walltime requirements)
	
	// Host Side Memory
	parameter HOST_MEM_ADDR=11,								// default to typical 2048x8 memories common to most 18kBit DPRAM blocks

	// MEMORY default configuration for a typical 8-pin SPI PSRAM
	parameter SRAM_ADDR_WIDTH=16,							// how many bits does the address have (e.g. 16 or 24)
	parameter DUMMY_CYCLES=6,								// how many dummy reads are required before the first byte is valid
	parameter CMD_READ=8'hEB,								// command to read 
	parameter CMD_WRITE=8'h38,								// command to write
	parameter CMD_EQIO=8'h35,								// command to enter quad IO mode
	parameter CMD_RESETEN=8'h66,							// command to enable reset
	parameter CMD_RESET=8'h99,								// command to reset
	parameter MIN_CPH_NS=50,								// how many ns must CS be high between commands (23LC's have a min time of mostly nothing)
	parameter MIN_WAKEUP_NS=150_000							// how many ns to wait for it to wakeup after POR
	parameter SPI_TIMER_BITS=4,								// divide clock by X for SPI operations
	parameter QPI_TIMER_BITS=1,								// divide clock by X for QPI operations
	parameter PSRAM_RESET=1									// do you need to send 66 99 to reset required by PSRAM chips?
)(
	input wire clk,											// clock
	input wire rst_n,										// active low reset

	// BUS
	output wire ready,										// active high means the module is done with a request
	
	// Host side memory
	output reg [HOST_MEM_ADDR-1:0] host_mem_addr,			// address to read/write to from host memory
	output reg host_mem_wr_en,								// write enable
	output reg [7:0] host_mem_data_in;						// data to write to host mem
	input  wire [7:0] host_mem_data_out;					// data read from host mem
	
	// Command data
	input wire [3:0] cmd_value,								// what command to run (read, write, ...)
	input wire cmd_valid,									// active high when all cmd signals are valid
	input wire [SRAM_ADDR_WIDTH-1:0] cmd_psram_address,		// address to read/write from the SPI device
	input wire [HOST_MEM_ADDR-1:0] cmd_host_address,		// address to write/read from the host memory
	input wire [5:0] cmd_burst_len,							// how many bytes to read (1..64)

	// I/O
	input wire [3:0] sio_din,
	output reg [3:0] sio_dout,
	output reg [3:0] sio_en,
	output wire cs_pin,											// active low CS pin
	output reg sck_pin											// SPI clock
);
`ifdef SIM_MODEL
	reg [3:0] sim_memory[(1<<(SRAM_ADDR_WIDTH+1))-1:0];
	reg [15:0] sim_address;
	reg [7:0] sim_dummy;
`endif

// TODO: handle assign sck_pin

	reg [3:0] state;										// What state is our FSM in
	reg [3:0] tag;
	reg [3:0] bit_cnt;										// bit counter a variety of FSM states

	reg [3:0] sck_timer;									// timer used to know when to change phase
	

	reg [20:0] hangup_timer;
	wire [20:0] hangup_bauddiv = ((CLK_FREQ_MHZ * MIN_CPH_NS + 999) / 1000);
	wire [20:0] wakeup_bauddiv = ((CLK_FREQ_MHZ * MIN_WAKEUP_NS + 999) / 1000);
	reg [7:0] temp_wire_bits;
	
/* ok changes....

1.  Do away with global timer and just count inside the FSM when you're sending/reading SPI or QPI, this will let us have a cycle between operations without SCK getting
    out of phase.  So the actual FSM state that transmits/receives SPI or QPI itself will count SPI_TIMER or QPI_TIMER when changing SCK.
    
2.  Drop all of the existing SEND/READ_2 code and write a generic QPI send/recv that handles 1 byte at a time (use tag to return to parent state for burst read or write)

3.  The parent state that calls SEND for writing data to SPI memory can initiate the "read next byte" while transmitting the current byte to the SPI memory
    - Note we will have to read byte 0 during the CMD phase and byte 1 will have to be issued right after that so by time we're ready to transmit byte 1 it's already read
    (e.g. when byte 0 finishes we tell the host to read byte 2, when byte 1 finishes we tell the host to read byte 3, etc...)

4.  The parent state that calls RECV to read data from the SPI memory can initiate the write to host memory once QPI comes back so host memory operations happen in parallel so there's
no waiting.
    - Here we wait for data from SPI memory, then once we finish shifting data in, we issue a write, and then shift in the next byte as needed.
    - The FSM that handles shifting in a QPI byte should disable the wr_en (save power) and also advance the host_mem_address so the next write is primed to go into 
    - the right address.

5.  The IDLE state will jump into a generic "transmit CMD + ADDR" state that then jumps into a read/write (from SPI memory) FSM that iterates over the burst length
    - The "CMD + ADDR" state would be largely for any addressed commands (sector erase, page program, read/write), for other commands we'll need their own FSM landing state

6.  Rename DUMMY_BYTES to DUMMY_CYCLES since that's what they are in reality

7.  Eventually I'll add a program_cmd and erase_sector_cmd to support NOR flash

*/
	
	localparam
		STATE_INIT					= 0,													// Initialize the SPI memory by putting into a quad-io mode
		STATE_INIT_DONE				= 1,													
		STATE_SEND_RESETEN			= 2,													// enable RESET
		STATE_SEND_RESETEN_DONE		= 3,
		STATE_SEND_RESET			= 4,													// issue RESET command
		STATE_SEND_RESET_DONE		= 5,
		STATE_SPI_SEND_8			= 6,													// Send a command in 1-bit SPI mode
		STATE_IDLE					= 7,													// Idle state waiting for a command
		STATE_HANGUP				= 8,													// Hang up SPI bus
		STATE_HANGUP_WAIT			= 9;													// hold CS high for a count

	always @(posedge clk) begin
		if (!rst_n) begin
            state			<= STATE_HANGUP_WAIT;						// Jump to initial FSM state
            tag				<= PSRAM_RESET == 1 ? STATE_SEND_RESETEN : STATE_INIT;
            hangup_timer    <= wakeup_bauddiv;
            sio_en			<= 4'b0000;									// disable all outputs
            sio_dout		<= 4'b1111;									// SPI bus output
            sck_pin			<= 1'b0;									// default low
            cs_pin			<= 1'b1;									// default high
            temp_wire_bits  <= 8'h00;
            bit_cnt			<= 4'h0;
            	
			// TODO: other initials

		end else begin
			case(state)
				STATE_SEND_RESETEN:										// Send 0x66 RESET ENABLE
					begin
						temp_wire_bits	<= CMD_RESETEN;
						bit_cnt			<= 7;
						state			<= STATE_SPI_SEND_8;
						tag				<= STATE_SEND_RESETEN_DONE;
						sio_en			<= 4'b0001;						// enable MOSI output pin SIO[0]
						sck_timer		<= SPI_TIMER_BITS;
					end
				STATE_SEND_RESETEN_DONE:								// done sending 0x66 RESET ENABLE, hangup and then issue RESET
					begin
						state			<= STATE_HANGUP;
						tag				<= STATE_SEND_RESET;
					end

				STATE_SEND_RESET:										// Send 0x99 RESET 
					begin
						temp_wire_bits	<= CMD_RESET;
						state			<= STATE_SPI_SEND_8;
						tag				<= STATE_SEND_RESET_DONE;
						sio_en			<= 4'b0001;						// enable MOSI output pin SIO[0]
					end
				STATE_SEND_RESET_DONE:								    // done sending 0x66 RESET ENABLE, hangup and then issue RESET
					begin
						state			<= STATE_HANGUP;
						tag				<= STATE_INIT;
					end

				STATE_INIT:												// send enter Quad I/O command
					begin
                        // sticking some STATE_INIT initializations here.
                        temp_wire_bits	<= CMD_EQIO;					// Send "enter quad mode IO" command
						state			<= STATE_SPI_SEND_8;			// Use single bit SEND state
						tag				<= STATE_INIT_DONE;
						sio_en			<= 4'b0001;						// enable MOSI output pin SIO[0]
					end
				STATE_INIT_DONE:
					begin
						state			<= STATE_HANGUP;
						tag				<= STATE_IDLE;
					end

				// input: sck_timer set to the count required 
				STATE_SPI_SEND_8:										// send 8 bits in temp_spi_bits (sio_en[0] = 1, bit_cnt = 8)	
					begin
						cs_pin <= 1'b0;									// default CS low 
						case(sck_pin)
							1'd0:										// SCK low phase, put data on wire
								begin
									// write during low
									sio_dout[0] <= temp_wire_bits[7];
									if (sck_timer == 0) begin
										sck_timer <= SPI_TIMER_BITS;	// time to switch to SCK high
										sck_pin   <= ~sck_pin;
									end else begin
										sck_timer <= sck_timer - 1'b1;
									end
								end
							1'd1:										// SCK high phase, keep data steady, move to next bit at end of phase
								begin
									if (sck_timer == 0) begin
										bit_cnt        <= bit_cnt - 1'b1;
										temp_wire_bits <= {temp_wire_bits[6:0], 1'b0};		// shift wire bits
										sck_pin        <= ~sck_pin;							// set SCK to low for either the next bit of this transaction or the start of the next transaction
										sck_timer      <= SPI_TIMER_BITS;					// reset timer in case we chain SEND_8's
										if (bit_cnt == 0) begin
											bit_cnt    <= 7;								// reset bit count in case we chain SEND_8's
											state      <= tag;
										end
									end else begin
										sck_timer <= sck_timer - 1'b1;
									end
								end
						endcase
					end

				STATE_HANGUP:																// hang up the SPI connection
					begin
						hangup_timer	<= hangup_bauddiv;		 							// ensure we hit the required MIN_CPH_NS time (round up for safety)
						state			<= STATE_HANGUP_WAIT;
						sio_en    		<= 4'b0000;											// disable outputs
						sio_dout		<= 4'b1111;
					end
				STATE_HANGUP_WAIT:															// Hangup and hold CS high for a mandatory period
					begin
						cs_pin		    <= 1'b1;											// reset CS to default of high
						sck_pin			<= 1'b0;											// reset SCK to default of low
						hangup_timer 	<= hangup_timer - 1'b1;
						if (hangup_timer == 0) begin
							state <= tag;													// Resume next state
						end
					end
				default:
					begin
					end
			endcase
		end
	end
endmodule
