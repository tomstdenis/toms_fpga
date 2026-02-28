`timescale 1ns/1ps
/* Implementation of FIFO based SPI SRAM

We assume the device inits in SPI mode and we need to send it command 0x38 to ender quad mode, then
from there we use command 0x03 to read sequential bytes and 0x02 to write.  We assume sequential
mode is the default (which is on the 23LC512 I'm testing this on).

The design is based on a 1/2 cycle pulse cadence.  The full SPI clock cycle is low
for pulse 0, and high for pulse 1.  This means we put data on dout in pulse 0,
and we read data from din on pulse 1.  since our FSM clocks faster than pulses we use prev_pulse
to detect the edge of a pulse.

The FSM works by realizing that all SRAM commands are just writes followed by optional reads.  So 
we form a payload of command + address + write payload, write that out, then if there are bytes
to read we switch to reading them (plus any dummy bytes).

To write to SRAM

	1.  Cycle 0: Load the next data into data_in, set data_in_valid
	2.  Cycles 1..N: goto 1.
	3.  cycle N+1: data_in_valid goes low, write_cmd goes high, address is set to the address
	4.  While !done goto 4
	5.  You're done writing.
	
To read SRAM

	1.  Cycle 0: Write read_cmd high, address, and read_cmd_size to the block size you want to read
	2.  Cycles 1..N: While !done goto 2
	3.  Cycle N+1...: Read data_out, set data_out_read high, goto 3 for the rest of the payload (you can use data_out_empty to tell when done easily)
	4.  data_out_read set low

Parameters are setup for 23LC class SPI SRAMs,

for PSRAMs you might need 
	
	DUMMY_BYTES=6 (FAST READ QUAD is the only valid QUAD read command, it has 6 dummy bytes)
	CMD_READ=8'hEB (QUAD FAST READ upto 100MHz usually)
	CMD_EQIO=8'h35 (ENTER QUAD IO mode)
	MIN_CPH_NS=50 min delay between commands, check your datasheets!
	quad_bauddiv: remember to set quad_bauddiv to the highest the SPI PSRAM supports (likely a bauddiv of 0 here)
	
		E.g. many PSRAMs can do SPI at ~33MHz and QDI at 100+MHz so if your system clock is say 80MHz you might want
		spi_bauddiv = 1 to get a 20 MHz clock and quad_bauddiv = 0 to get a 40MHz clock

*/

module spi_sram_fifo #(
	parameter CLK_FREQ_MHZ=27,								// system clock frequency (required for walltime requirements)
	parameter FIFO_DEPTH=32,								// controls the max burst size

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

	output done,											// active high means the module is done with a request
	
	input [31:0] data_in,									// data we want to write to the core
	input data_in_valid,									// active high indicates the user wants to send data to the outgoing FIFO
	output [31:0] data_out,									// assigned fifo[read_ptr]
	input [3:0] data_be,									// byte enables
	input data_out_read,									// active high indicates read_ptr should be incremented
	output data_out_empty,									// active high when all data read from the SPI SRAM is read from the fifo
	
	input write_cmd,										// active high we're doing a write
	input read_cmd,											// active high we're doing a read
	input [$clog2(FIFO_DEPTH):0] read_cmd_size,				// how many bytes the user wants to read
	input [23:0] address,									// address to read/write from

	inout [3:0] sio_pin,									// data pins
	output cs_pin,											// active low CS pin
	output sck_pin											// SPI clock
);
`ifdef SIM_MODEL
	reg [7:0] sim_memory[65535:0];
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
	
	// total size of fifo including cmd, address, dummy bytes and max size payload
	localparam FIFO_TOTAL_SIZE = 1 + FIFO_DEPTH + (SRAM_ADDR_WIDTH/8) + DUMMY_BYTES;
	
	wire spi_pulse;
	wire qpi_pulse;
	reg spi_prev_pulse;											// previous pulse to detect edge of pulse
	reg qpi_prev_pulse;											// previous pulse to detect edge of pulse
	reg [7:0] fifo[FIFO_TOTAL_SIZE-1:0];					// our SRAM FIFO
	reg [$clog2(FIFO_TOTAL_SIZE):0] fifo_wptr;				// our SRAM FIFO write pointer (incremented by data_in_valid)
	reg [$clog2(FIFO_TOTAL_SIZE):0] read_cmd_wptr;			// copy of WPTR from a SPI SRAM read.
	reg [$clog2(FIFO_TOTAL_SIZE):0] fifo_rptr;				// our SRAM FIFO read pointer (incremented by data_out_read)
	reg [$clog2(FIFO_DEPTH)+1:0] bytes_to_read;				// How many bytes left to read
	
	reg [3:0] state;										// What state is our FSM in
	reg [3:0] tag;											// return point for sub-states.
	reg [7:0] temp_bits;									// temp bits for single SPI being written or read
	reg [3:0] bit_cnt;										// bit counter for sending initial 0x38 etc

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
			qpi_prev_pulse <= 1'b1;								// init prev to 1 so the first pass detects the edge if needed
		end else if (busy) begin
			timer <= timer + 1'b1;
			spi_prev_pulse <= spi_pulse;
			qpi_prev_pulse <= qpi_pulse;
		end
	end
	
	localparam
		STATE_INIT=0,
		STATE_SPI_SEND_8=1,
		STATE_IDLE=2,
		STATE_STORE_ADDR_1=3,
		STATE_STORE_ADDR_2=4,
		STATE_STORE_ADDR_3=5,
		STATE_SPI_SEND_2=6,
		STATE_SPI_READ_2=7,
		STATE_POST_WRITE=8,
		STATE_POST_READ=9,
		STATE_HANGUP=10,
		STATE_HANGUP_WAIT=11;

	assign cs_pin 		= ~busy;															// active low CS pin
	assign spi_pulse 	= timer[SPI_TIMER_BITS-1];											// SPI timed pulses
	assign qpi_pulse 	= timer[QPI_TIMER_BITS-1];											// QPI timed pulses
	assign sck_pin 		= busy & (state == STATE_SPI_SEND_8 ? spi_pulse : qpi_pulse);		// The SCK pin depending on if we're doing SPI or QPI traffic
	assign done			= (state == STATE_IDLE);											// 'done' is basically a "are we at idle" flag

	wire [$clog2(FIFO_TOTAL_SIZE)-1:0] fifo_r = fifo_rptr[$clog2(FIFO_TOTAL_SIZE)-1:0];    // shorthand for read index into FIFO
	wire [$clog2(FIFO_TOTAL_SIZE)-1:0] fifo_w = fifo_wptr[$clog2(FIFO_TOTAL_SIZE)-1:0];	// shorthand for write index into FIFO
	
	wire [$clog2(FIFO_TOTAL_SIZE)-1:0]be_bytes  = (data_be == 4'b1111) ? 4 :
							((data_be == 4'b0011) ? 2 : 1);
	assign data_out = { 
						data_be[3] ? fifo[fifo_r + 3] : 8'b0,
						data_be[2] ? fifo[fifo_r + 2] : 8'b0,
						data_be[1] ? fifo[fifo_r + 1] : 8'b0,
						fifo[fifo_r]
					  };
	assign data_out_empty = (fifo_rptr >= read_cmd_wptr) ? 1'b1 : 1'b0;

	always @(posedge clk) begin
		if (!rst_n) begin
            fifo_wptr <= 1 + (SRAM_ADDR_WIDTH/8);			// user data goes after the write command and address bytes
            fifo_rptr <= 0;
            read_cmd_wptr <= 0;
            state <= STATE_INIT;
            temp_bits <= 0;
            sio_en <= 4'b0000;								// disable all outputs
            fifo[0] <= 0;									// ensure data_out is initialized 
            dout <= 0;
            busy <= 0;
            doing_read <= 0;
            bytes_to_read <= 0;
		end else begin
			case(state)
				STATE_INIT:
					begin
                        // sticking some STATE_INIT initializations here.
                        temp_spi_bits	<= CMD_EQIO;			// Send "enter quad mode IO" command
                        bit_cnt			<= 8;					// we use single bit SPI mode for this command
                        tag 			<= STATE_HANGUP;		// We need to deselect the chip for a hold timing before we can submit the next command
						state			<= STATE_SPI_SEND_8;	// Use single bit SEND state
						sio_en			<= 4'b0001;				// enable MOSI output pin SIO[0]
						busy			<= 1;					// start SPI clock
					end
				STATE_SPI_SEND_8:								// send 8 bits in temp_spi_bits (sio_en[0] = 1, bit_cnt = 8)	
					begin
						case(spi_pulse)
							1'd0:								// we put data on the line mid way through the first half cycle
								begin
									if (spi_prev_pulse != spi_pulse) begin			// we detect edges of the pulse so we only process the state once
										dout[0] <= temp_spi_bits[7];
									end
								end
							1'd1:							// Detect if we should exit this loop
								begin
									if (timer == ((1 << SPI_TIMER_BITS) - 1)) begin	// only move on the last system clock cycle of the SPI clock cycle
										bit_cnt <= bit_cnt - 1'b1;
										temp_spi_bits <= {temp_spi_bits[6:0], 1'b0};
										if (bit_cnt == 1) begin						// we stop at 1 since we execute first then check
											busy   <= 0;
											state  <= STATE_POST_WRITE;
										end
									end
								end
						endcase
					end
				STATE_SPI_SEND_2:							// write nibbles from fifo_rptr to fifo_wptr, then if read_cmd switch to reads
					begin
						if (qpi_prev_pulse != qpi_pulse) begin						
							case(qpi_pulse)
								1'd0:							// we put data on the line in the first half cycle
									begin
`ifdef SIM_MODEL
	if (fifo_rptr >= (1 + (SRAM_ADDR_WIDTH/8))) begin
		if (bit_cnt == 2) begin
			sim_memory[sim_address] <= {temp_bits[7:4], sim_memory[sim_address][3:0]};
		end else begin
			sim_memory[sim_address] <= {sim_memory[sim_address][7:4], temp_bits[7:4]};
			sim_address <= sim_address + 1'b1;
			$display("Wrote %2h to %4h", {sim_memory[sim_address][7:4], temp_bits[7:4]}, sim_address);
		end
	end
`endif
										dout <= temp_bits[7:4];					// in quad mode we shift out the most significant nibble first
									end
								1'd1:							// Detect if we should exit from this loop
									begin
										// if there are more bytes to send ...
										if (bit_cnt == 1) begin
											bit_cnt		<= 2;
											temp_bits	<= data_out[7:0]; // fifo[fifo_rptr[$clog2(FIFO_TOTAL_SIZE)-1:0]];
											fifo_rptr	<= fifo_rptr + 1'b1;
											if (fifo_rptr == fifo_wptr) begin
												bytes_to_read 	<= read_cmd_size + DUMMY_BYTES;
												state			<= tag;
												busy			<= doing_read;
											end
										end else begin
											bit_cnt <= bit_cnt - 1'b1;
											temp_bits <= {temp_bits[3:0], 4'b0};
										end
									end
							endcase
						end
					end
				STATE_SPI_READ_2:							// read from the SPI SRAM upto DUMMY_READ + read_cmd_size bytes
					begin
						if (qpi_prev_pulse != qpi_pulse) begin
							case(qpi_pulse)
								1'd0:
									begin
										sio_en <= 4'b0000;		// disable all four outputs
									end
								1'd1:							// we sample during the 2nd half of the cycle
									begin
`ifdef SIM_MODEL
	if (sim_dummy == 0) begin
		if (bit_cnt == 2) begin
			temp_bits <= {4'b0, sim_memory[sim_address][7:4]};
		end else begin
			temp_bits <= {temp_bits[3:0], sim_memory[sim_address][3:0]};
			sim_address <= sim_address + 1'b1;
			$display("We read %2h from %4h", {temp_bits[3:0], sim_memory[sim_address][3:0]}, sim_address);
		end
	end else begin
		$display("dummy == %d", sim_dummy);
		sim_dummy <= sim_dummy - 1'b1;
	end
`else
										temp_bits <= {4'b0, din};				// Store high nibble of input 
`endif
										if (bit_cnt == 1) begin					// we do the work before checking the counter so we stop at 1 not 0
											// write next byte we read out, this starts just after the cmd and address 
`ifdef SIM_MODEL
											fifo[fifo_w] <= {temp_bits[3:0], sim_memory[sim_address][3:0]};
`else
											fifo[fifo_w] <= { temp_bits[3:0], din };
`endif
											fifo_wptr <= fifo_wptr + 1'b1;
											if (bytes_to_read == 1) begin
												// if we only had 1 byte left we're done
												state <= STATE_POST_READ;
												busy  <= 0;
											end else begin
												bit_cnt <= 2;
												bytes_to_read <= bytes_to_read - 1'b1;
											end
										end else begin 
											bit_cnt <= bit_cnt - 1'b1;
										end
									end
							endcase
						end
					end
				STATE_IDLE:
					begin
						if (data_in_valid) begin // user is writing data to the FIFO to eventually write to SPI SRAM
							// payload goes after the cmd and address
							// note we don't add DUMMY_BYTES here since it's not used in write commands
							// which also means if you write here and then do read_cmd it'll send out a bogus stream confusing the SPI SRAM
							fifo[fifo_w] <= data_in[7:0];
							if (data_be[1]) begin fifo[fifo_w + 1] <= data_in[15:8]; end
							if (data_be[2]) begin fifo[fifo_w + 2] <= data_in[23:16]; end
							if (data_be[3]) begin fifo[fifo_w + 3] <= data_in[31:24]; end
							fifo_wptr <= fifo_wptr + be_bytes;
						end
						
						if (data_out_read) begin // user is reading from FIFO
							// after a command wptr is after cmd + address + dummy + payload
							// rptr is left to just after cmd + address + dummy
							fifo_rptr <= fifo_rptr + be_bytes;
						end
						
						if (write_cmd | read_cmd) begin		// user wants to issue a read or write so we prepare the SPI write (command + address + optional payload)
							sio_en 		<= 4'b1111;			// enable all 4 outputs
							temp_bits 	<= (write_cmd == 1) ? CMD_WRITE : CMD_READ;	// first byte we send has to be in temp_bits and it's the command, no need to load fifo[0]
							tag         <= (write_cmd == 1) ? STATE_POST_WRITE : STATE_SPI_READ_2;
							doing_read  <= read_cmd;
							state		<= STATE_SPI_SEND_2;
							fifo_rptr <= 1;
							bit_cnt <= 2;
							busy <= 1;
							if (SRAM_ADDR_WIDTH == 24) begin
								fifo[1] <= address[23:16];
								fifo[2] <= address[15:8];
								fifo[3] <= address[7:0];
							end else begin
								fifo[1] <= address[15:8];
								fifo[2] <= address[7:0];
							end
                        `ifdef SIM_MODEL
                            sim_dummy <= DUMMY_BYTES[7:0] * 2;
                            sim_address <= address[15:0];
                        `endif
						end
					end
				STATE_POST_WRITE: // after a write command
					begin
						sio_en    		<= 4'b0000;						// disable outputs
						fifo_rptr 		<= 0;							// reset rptr so we can read it during next submission
						state 	  		<= STATE_HANGUP;
					end
				STATE_POST_READ: // after a read command
					begin
						fifo_rptr	  <= 1 + (SRAM_ADDR_WIDTH/8) + DUMMY_BYTES;	// set to just after command + address + dummy bytes
						read_cmd_wptr <= fifo_wptr;
						state		  <= STATE_HANGUP;
					end
				STATE_HANGUP:		// hang up the SPI connection
					begin
						hangup_timer	<= hangup_bauddiv[7:0]; // ensure we hit the required MIN_CPH_NS time (round up for safety)
						fifo_wptr    	<= 1 + (SRAM_ADDR_WIDTH/8);
						state			<= STATE_HANGUP_WAIT;
					end
				STATE_HANGUP_WAIT:
					begin
						hangup_timer <= hangup_timer - 1'b1;
						if (hangup_timer == 0) begin
							state <= STATE_IDLE;
						end
					end
				default:
					begin
					end
			endcase
		end
	end
endmodule
