/* Flat register base SRAM driver

This is a variant of sram_flat.v where the QPI clock
is the module clock.  This is meant for designs that operate at sub ~100-120MHz (within
the PSRAM/SRAM clock speed).  In this module the QPI clock
runs at your module clock meaning you can still have a fast read/write cycle.

The SPI_TIMER_BITS is still provided so you can divide down the initial SPI clock if you need
to.  Typically, PSRAMs/SRAMs want a SPI clock below 40MHz or so.

This module implements a Quad IO (SPI) based PSRAM/SRAM interface
that is meant to provide a single unit of data access at a time.

On the lower end DATA_WIDTH=32 gives a CPU friendly interface to
memory (albeit with high latency) with byte enables that shift data
around as required.

On the upper end DATA_WIDTH >= 128 can be used by a cache or scan line
controller to access an entire lines worth of data.  Really only
limited by the enable time of the CS pin (typically has to be less
than 4 uS).

*/
`timescale 1ns/1ps
module spi_sram_flat_zc #(
	parameter CLK_FREQ_MHZ=27,								// system clock frequency (required for walltime requirements)
	parameter DATA_WIDTH=32,								// controls the line size

	// default configuration for a 23LC512 (20MHz max QPI rate)
	parameter SRAM_ADDR_WIDTH=16,							// how many bits does the address have (e.g. 16 or 24)
	parameter DUMMY_BYTES=1,								// how many dummy reads are required before the first byte is valid
	parameter CMD_READ=8'h03,								// command to read 
	parameter CMD_WRITE=8'h02,								// command to write
	parameter CMD_EQIO=8'h38,								// command to enter quad IO mode
	parameter MIN_CPH_NS=5,									// how many ns must CS be high between commands (23LC's have a min time of mostly nothing)
	parameter SPI_TIMER_BITS=4								// divide clock by 16 for SPI operations
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
`ifdef SIM_MODEL
	reg [7:0] sim_memory[(1<<SRAM_ADDR_WIDTH)-1:0];
	reg [15:0] sim_address;
	reg [7:0] sim_dummy;
`endif

	reg [SPI_TIMER_BITS-1:0] timer;

	reg [3:0] dout;											// our output to the SPI bus
	reg [3:0] sio_en;										// per lane output enables 

	assign sio_pin[0] = sio_en[0] ? dout[0] : 1'bz;
	assign sio_pin[1] = sio_en[1] ? dout[1] : 1'bz;
	assign sio_pin[2] = sio_en[2] ? dout[2] : 1'bz;
	assign sio_pin[3] = sio_en[3] ? dout[3] : 1'bz;
	wire [3:0] din = sio_pin;
	
	// SEND wire
	// total size of send wire
	localparam SEND_SIZE = 8 + (SRAM_ADDR_WIDTH) + DATA_WIDTH;
	localparam READ_SIZE = 8 + SRAM_ADDR_WIDTH;
	reg [SRAM_ADDR_WIDTH-1:0] send_address;					// latched address
	reg [DATA_WIDTH-1:0] send_data;							// latched data to send
	reg [7:0] send_cmd;										// the command byte to send
	wire [7:0] cmd_byte = (write_cmd == 1) ? CMD_WRITE : CMD_READ;
	// thes wires forms the basic command we send when doing a read or a write
	wire [SEND_SIZE-1:0] send_wire = { send_cmd, send_address, send_data };
	wire [READ_SIZE-1:0] read_wire = { send_cmd, send_address };

	reg [3:0] read_data_be;									// latch the data_be
	
	wire spi_pulse;
	reg spi_prev_pulse;										// previous pulse to detect edge of pulse
	
	reg [2:0] state;										// What state is our FSM in
	reg [3:0] bit_cnt;										// bit counter a variety of FSM states
	reg [$clog2(DUMMY_BYTES*2):0] dummy_nibbles;			// how many nibbles to ignore
	reg [$clog2(SEND_SIZE)-1:0] nibble_idx;					// index into reg/wires in steps of 4 bits
	reg [$clog2(SEND_SIZE)-1:0] nibble_stop;				// index into reg/wires in steps of 4 bits

	reg [7:0] hangup_timer;
	wire [15:0] hangup_bauddiv = ((CLK_FREQ_MHZ * MIN_CPH_NS + 999) / 1000);
	reg busy;
	reg doing_read;
	reg [7:0] temp_spi_bits;
	
	// the SPI pulses FSM
	always @(posedge clk) begin
		if (!rst_n || !busy) begin
			timer <= 0;
			spi_prev_pulse <= 1'b1;								// init prev to 1 so the first pass detects the edge if needed
		end else if (busy) begin
			timer <= timer + 1'b1;
			spi_prev_pulse <= spi_pulse;
		end
	end
	
	localparam
		STATE_INIT					= 0,													// Initialize the SPI memory by putting into a quad-io mode
		STATE_SPI_SEND_8			= 1,													// Send a command in 1-bit SPI
		STATE_IDLE					= 2,													// Idle state waiting for a command
		STATE_SPI_SEND_2_WRITE		= 3,													// Send out a WRITE command over QPI
		STATE_SPI_SEND_2_READ		= 4,													// Send out a READ command over QPI
		STATE_SPI_READ_2			= 5,													// Read dummy + line data over QPI
		STATE_HANGUP				= 6,													// Hang up SPI bus
		STATE_HANGUP_WAIT			= 7;													// hold CS high for a count

	assign cs_pin 		= ~busy;															// active low CS pin
	assign spi_pulse 	= timer[SPI_TIMER_BITS-1];											// SPI timed pulses
	assign done			= (state == STATE_IDLE);											// 'done' is basically a "are we at idle" flag
	
	// assign data out
	always @(*) begin
		if (busy) begin
			case (state)
				STATE_SPI_SEND_8: 													sck_pin = spi_pulse;	// use SPI clock when doing SPI stuff
				STATE_SPI_SEND_2_READ, STATE_SPI_SEND_2_WRITE, STATE_SPI_READ_2: 	sck_pin = clk;			// Use system clock
				default: sck_pin = 1'b0;																	// default is off
			endcase
		end else begin
			sck_pin = 1'b0;																					// default is off
		end
		if (DATA_WIDTH == 32) begin
			case (read_data_be)
				4'b1111: data_out = send_data;
				4'b0011: data_out = {{(DATA_WIDTH-16){1'b0}}, send_data[15:0]};			// data comes into the MSB side of send_data first
				default: data_out = {{(DATA_WIDTH-8){1'b0}}, send_data[7:0]};
			endcase
		end else begin
			data_out = send_data;
		end
	end
	
	always @(posedge clk) begin
		if (!rst_n) begin
            state			<= STATE_INIT;								// Jump to initial FSM state
            sio_en			<= 4'b0000;									// disable all outputs
            dout			<= 0;										// SPI bus output
            busy			<= 0;										// busy flag (controls CS pin)
            send_address	<= 0;										// latched address
            send_data		<= 0;										// latched data
            send_cmd		<= 0;										// latched memory command
            dummy_nibbles   <= 0;
            nibble_idx      <= 0;
		end else begin
			case(state)
				STATE_INIT:
					begin
                        // sticking some STATE_INIT initializations here.
                        temp_spi_bits	<= CMD_EQIO;					// Send "enter quad mode IO" command
                        bit_cnt			<= 7;							// we use single bit SPI mode for this command
						state			<= STATE_SPI_SEND_8;			// Use single bit SEND state
						sio_en			<= 4'b0001;						// enable MOSI output pin SIO[0]
						busy			<= 1;							// start SPI clock
					end
				STATE_SPI_SEND_8:										// send 8 bits in temp_spi_bits (sio_en[0] = 1, bit_cnt = 8)	
					begin
						case(spi_pulse)
							1'd0:										// we put data on the line mid way through the first half cycle
								begin
									if (spi_prev_pulse != spi_pulse) begin			// we detect edges of the pulse so we only process the state once
										dout[0] <= temp_spi_bits[7];
									end
								end
							1'd1:										// Detect if we should exit this loop
								begin
									if (timer == ((1 << SPI_TIMER_BITS) - 1)) begin	// only move on the last system clock cycle of the SPI clock cycle
										bit_cnt <= bit_cnt - 1'b1;
										temp_spi_bits <= {temp_spi_bits[6:0], 1'b0};
										if (bit_cnt == 0) begin
											busy   <= 0;
											state  <= STATE_HANGUP;
										end
									end
								end
						endcase
					end
				STATE_SPI_SEND_2_WRITE:									// WRITE: Write the cmd + address + line in QPI mode
					begin
`ifdef SIM_MODEL
						if (nibble_idx < DATA_WIDTH) begin
							if (nibble_idx[2]) begin
								// sending the top nibble
								sim_memory[sim_address] <= {send_wire[nibble_idx +: 4], 4'h0 };
							end else begin
								sim_memory[sim_address] <= {sim_memory[sim_address][7:4], send_wire[nibble_idx +: 4]};
								$display("Wrote %h%h to %h", sim_memory[sim_address][7:4], send_wire[nibble_idx +: 4], sim_address);
								sim_address 			<= sim_address + 1;
							end
						end
`endif
						dout <= send_wire[(nibble_idx - 4) +: 4];	// in quad mode we shift out the most significant nibble first
																	// note we sub 4 here because in IDLE we loaded the first nibble into dout
						// if there are more bytes to send ...
						nibble_idx  <= nibble_idx - 4;
						if (nibble_idx == nibble_stop) begin
							state			<= STATE_HANGUP;
							busy			<= 0;					// it was a write command so we're done
						end
					end
				STATE_SPI_SEND_2_READ:												// READ: Write the cmd + address in QPI mode
					begin
						dout <= read_wire[(nibble_idx[$clog2(READ_SIZE)-1:0] - 4) +: 4];	// in quad mode we shift out the most significant nibble first
																							// sub 4 here because in IDLE we load the first nibble into dout
						// if there are more bytes to send ...
						nibble_idx  <= nibble_idx - 4;
						if (nibble_idx == nibble_stop) begin
							state			<= STATE_SPI_READ_2;					// jump to reading
							sio_en			<= 4'b0000;								// turn off output enables
							dummy_nibbles   <= (DUMMY_BYTES * 2);
							if (DATA_WIDTH == 32) begin
								case(read_data_be)
									4'b1111: // 32-bit operation
										begin
											nibble_idx      <= DATA_WIDTH - 4;		// start at the most significant nibble of the send_cmd byte
										end
									4'b0011: // 16-bit operation
										begin
											nibble_idx      <= DATA_WIDTH - 4 - 16;  // sub 4 so we can match without using a computed sub (sub 16 since we're only sending 16 bits out of 32)
										end
									default: // default to 8 bit
										begin
											nibble_idx      <= DATA_WIDTH - 4 - 24; // sub 4 so we can match without using a computed sub (sub 24 since we're only sending 8 bits out of 32)
										end
								endcase
							end else begin
								nibble_idx <= DATA_WIDTH - 4;
							end
						end
					end
				STATE_SPI_READ_2:							// read from the SPI SRAM upto DUMMY_READ + read_cmd_size bytes
					begin
`ifdef SIM_MODEL
						if (nibble_idx < DATA_WIDTH) begin
							if (nibble_idx[2]) begin
								send_data[nibble_idx[$clog2(DATA_WIDTH)-1:0] +: 4] <= sim_memory[sim_address][7:4]; // store top nibble
							end else begin
								send_data[nibble_idx[$clog2(DATA_WIDTH)-1:0] +: 4] <= sim_memory[sim_address][3:0]; // store bottom nibble
								$display("Read %h from %h", sim_memory[sim_address], sim_address);
								if (dummy_nibbles == 0) begin
									sim_address <= sim_address + 1;
								end
							end
						end
`else
						send_data[nibble_idx[$clog2(DATA_WIDTH)-1:0] +: 4] <= din; // store nibble
`endif
						// write next byte we read out, this starts just after the cmd and address 
						if (dummy_nibbles == 0) begin
							nibble_idx		<= nibble_idx - 4;
						end else begin
							dummy_nibbles	<= dummy_nibbles - 1;
						end
						if (nibble_idx == 0) begin
							state <= STATE_HANGUP;
							busy  <= 0;
						end
					end
				STATE_IDLE:																	// IDLE state, we look for data_in_valid, write_cmd, read_cmd here
					begin
						if (data_in_valid) begin
							if (DATA_WIDTH == 32) begin
								case(data_be)
									4'b1111: // 32-bit operation
										begin
											send_data <= data_in;
										end
									4'b0011: // 16-bit operation
										begin
											send_data <= { data_in[15:0], {(DATA_WIDTH-16){1'b0}} };
										end
									default: // default to 8 bit
										begin
											send_data <= { data_in[7:0], {(DATA_WIDTH-8){1'b0}} };
										end
								endcase
							end else begin
								send_data 		<= data_in;
							end
						end
						
						if (write_cmd | read_cmd) begin																// user wants to issue a read or write so we prepare the SPI write (command + address + optional payload)
							sio_en 			<= 4'b1111;																// enable all 4 outputs
							dout			<= cmd_byte[7:4];														// preload output for 1-cycle cadence
							send_cmd 		<= cmd_byte;															// the SPI command we need
							send_address	<= address;																// latch the address
							state			<= (write_cmd == 1) ? STATE_SPI_SEND_2_WRITE : STATE_SPI_SEND_2_READ;	// jump to state relevant to the operation requested
							busy 			<= 1;																	// we're going to be busy in the next cycle
							read_data_be	<= data_be;																// latch the data_be so we can use it during reads
							nibble_idx 		<= SEND_SIZE - 4;
							if (write_cmd) begin
								if (DATA_WIDTH == 32) begin
									case(data_be)
										4'b1111: // 32-bit operation
											begin
												nibble_stop		 <= 0;		// full transfer
											end
										4'b0011: // 16-bit operation
											begin
												nibble_stop      <= 16;		// stop with 16 bits left since we're only writing 16
											end
										default: // default to 8 bit
											begin
												nibble_stop      <= 24;		// stop with 24 bits left since we're only writing 8
											end
									endcase
								end else begin
									nibble_stop <= 0;
								end
							end else begin
								// read commands are just the cmd + address
								nibble_idx <= 8 + SRAM_ADDR_WIDTH - 4;
								nibble_stop <= 0;
							end
                        `ifdef SIM_MODEL
                            sim_dummy <= DUMMY_BYTES[7:0] * 2;
                            sim_address <= address[15:0];
                        `endif
						end
					end
				STATE_HANGUP:																// hang up the SPI connection
					begin
						sio_en    		<= 4'b0000;											// disable outputs
						hangup_timer	<= hangup_bauddiv[7:0]; 							// ensure we hit the required MIN_CPH_NS time (round up for safety)
						state			<= STATE_HANGUP_WAIT;
					end
				STATE_HANGUP_WAIT:															// Hangup and hold CS high for a mandatory period
					begin
						hangup_timer 	<= hangup_timer - 1'b1;
						if (hangup_timer == 0) begin
							state <= STATE_IDLE;											// Resume IDLE state
						end
					end
				default:
					begin
					end
			endcase
		end
	end
endmodule
