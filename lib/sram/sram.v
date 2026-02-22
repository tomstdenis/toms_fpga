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

module spi_sram #(
	parameter CLK_FREQ_MHZ=27,								// system clock frequency (required for walltime requirements)
	parameter FIFO_DEPTH=32,								// controls the max burst size
	parameter SRAM_ADDR_WIDTH=16,							// how many bits does the address have (e.g. 16 or 24)
	parameter DUMMY_BYTES=1,								// how many dummy reads are required before the first byte is valid
	parameter CMD_READ=8'h03,								// command to read 
	parameter CMD_WRITE=8'h02,								// command to write
	parameter CMD_EQIO=8'h38,								// command to enter quad IO mode
	parameter MIN_CPH_NS=5									// how many ns must CS be high between commands (23LC's have a min time of mostly nothing)
)(
	input clk,												// clock
	input rst_n,											// active low reset

	output reg done,										// active high means the module is done with a request
	
	input [7:0] data_in,									// data we want to write to the core
	input data_in_valid,									// active high indicates the user wants to send data to the outgoing FIFO
	output [7:0] data_out,									// assigned fifo[read_ptr]
	input data_out_read,									// active high indicates read_ptr should be incremented
	output data_out_empty,									// active high when all data read from the SPI SRAM is read from the fifo
	
	input write_cmd,										// active high we're doing a write
	input read_cmd,											// active high we're doing a read
	input [$clog2(FIFO_DEPTH):0] read_cmd_size,		// how many bytes the user wants to read
	input [23:0] address,									// address to read/write from

	inout [3:0] sio_pin,									// data pins
	output reg cs_pin,										// active low CS pin
	output reg sck_pin,										// SPI clock
	input [11:0] spi_bauddiv,								// Sets the SPI SCLK rate to CLK_FREQ_MHZ/(spi_bauddiv+1)
	input [11:0] quad_bauddiv								// Sets the QPI SCLK rate to CLK_FREQ_MHZ/(quad_bauddiv+1), allowing a higher QPI clock than SPI
);

	reg [3:0] dout;											// our output to the SPI bus
	reg [3:0] sio_en;										// per lane output enables 
	reg [11:0] bauddiv;

	assign sio_pin[0] = sio_en[0] ? dout[0] : 1'bz;
	assign sio_pin[1] = sio_en[1] ? dout[1] : 1'bz;
	assign sio_pin[2] = sio_en[2] ? dout[2] : 1'bz;
	assign sio_pin[3] = sio_en[3] ? dout[3] : 1'bz;
	wire [3:0] din = sio_pin;
	
	// total size of fifo including cmd, address, dummy bytes and max size payload
	localparam FIFO_TOTAL_SIZE = 1 + FIFO_DEPTH + (SRAM_ADDR_WIDTH/8) + DUMMY_BYTES;
	
	reg pulse;												// what part of the 1/4th cycle are we in?
	reg prev_pulse;											// previous pulse to detect edge of pulse
	reg [11:0] timer;										// timer to advance pulse
	reg [7:0] fifo[FIFO_TOTAL_SIZE-1:0];					// our SRAM FIFO
	reg [$clog2(FIFO_TOTAL_SIZE):0] fifo_wptr;					// our SRAM FIFO write pointer (incremented by data_in_valid)
	reg [$clog2(FIFO_TOTAL_SIZE):0] read_cmd_wptr;				// copy of WPTR from a SPI SRAM read.
	reg [$clog2(FIFO_TOTAL_SIZE):0] fifo_rptr;					// our SRAM FIFO read pointer (incremented by data_out_read)
	reg [$clog2(FIFO_TOTAL_SIZE):0] bytes_to_read;				// our SRAM FIFO read pointer (incremented by data_out_read)
	assign data_out = fifo[fifo_rptr[$clog2(FIFO_TOTAL_SIZE)-1:0]];	// assign output byte combinatorially	
	assign data_out_empty = (fifo_rptr == read_cmd_wptr) ? 1'b1 : 1'b0;
	
	reg [3:0] state;										// What state is our FSM in
	reg [3:0] tag;											// return point for sub-states.
	reg [$clog2(DUMMY_BYTES):0] dummy_cnt;					// how many dummy bytes left to discard
	reg [7:0] temp_bits;									// temp bits for single SPI being written or read
	reg [3:0] bit_cnt;										// bit counter for sending initial 0x38 etc

	reg [7:0] hangup_timer;
	wire [15:0] hangup_bauddiv = ((CLK_FREQ_MHZ * MIN_CPH_NS + 999) / 1000);
	reg busy;
	reg doing_read;
	reg [7:0] temp_spi_bits;
	
	// the SPI pulses FSM
	always @(posedge clk) begin
		if (!rst_n) begin
			timer <= bauddiv;
			pulse <= 0;
			prev_pulse <= 1'b1;								// init prev to 1 so the first pass detects the edge if needed
			sck_pin <= 0;									// ensure SPI SCK is low during init
		end else begin
			if (busy) begin									// only run SPI pulses if the module is busy
				prev_pulse <= pulse;						// latch previous value of pulse
				if (bauddiv > 0 && timer > 0) begin
					timer <= timer - 1'b1;
				end else begin
					pulse <= ~pulse;
					sck_pin <= ~pulse;
					timer <= bauddiv;
				end
			end else begin
				// we're idle so reset pulse
				timer <= bauddiv;
				pulse <= 0;
				prev_pulse <= 1'b1;
				sck_pin <= 1'b0;							// ensure SPI clk is low if not busy
			end
		end
	end
	
	localparam
		STATE_INIT=0,
		STATE_IDLE=1,
		STATE_SPI_SEND_8=2,
		STATE_SPI_SEND_2=3,
		STATE_SPI_READ_2=4,
		STATE_POST_WRITE=5,
		STATE_POST_READ=6,
		STATE_HANGUP=7,
		STATE_CMD_START_DELAY=8,
		STATE_INIT_CMD_EQIO=9,
		STATE_STORE_ADDR_1=10,
		STATE_STORE_ADDR_2=11,
		STATE_STORE_ADDR_3=12;

	always @(posedge clk) begin
		if (!rst_n) begin
			fifo_wptr <= 1 + (SRAM_ADDR_WIDTH/8);			// user data goes after the write command and address bytes
			fifo_rptr <= 0;
			state <= STATE_INIT;
			dummy_cnt <= DUMMY_BYTES;
			temp_bits <= 0;
			bit_cnt <= 0;
			sio_en <= 4'b0000;								// disable all outputs
			cs_pin <= 1'b1;									// ensure chip isn't selected
			fifo[0] <= 0;									// ensure data_out is initialized 
			dout <= 0;
			busy <= 0;
			done <= 0;
			bauddiv <= spi_bauddiv;							// we initially use the slower single bit SPI mode timing
			doing_read <= 0;
			bytes_to_read <= 0;
			temp_spi_bits <= 0;
		end else begin
			case(state)
				STATE_INIT:
					begin
						// prepare to send SPI command 0x38 to enter quad mode
						bauddiv		<= spi_bauddiv;				// if we somehow jump back to init let's ensure bauddiv is set correctly
						temp_spi_bits	<= CMD_EQIO;				// enter quad mode
						bit_cnt		<= 8;						// 8 bits to send
						state		<= STATE_SPI_SEND_8;
						tag			<= STATE_IDLE;
						cs_pin		<= 1'b0;					// assert CS to wake the device
						sio_en		<= 4'b0001;					// enable MOSI output pin SIO[0]
						busy		<= 1;						// start SPI clock
					end
				STATE_SPI_SEND_8:							// send 8 bits in temp_bits (sio_en[0] = 1, bit_cnt = 8)	
					begin
						case(pulse)
							1'd0:							// we put data on the line mid way through the first half cycle
								begin
									if (prev_pulse != pulse) begin			// we detect edges of the pulse so we only process the state once
										dout[0] <= temp_spi_bits[7];
										temp_spi_bits <= {temp_spi_bits[6:0], 1'b0};
									end
								end
							1'd1:							// Detect if we should exit this loop
								begin
									if (timer == bauddiv - 1) begin			// only move on the last system clock cycle of the SPI clock cycle
										if (bit_cnt == 1) begin				// we stop at 1 since we execute first then check
											sio_en <= 4'b0000;				// done sending disable outputs
											busy   <= 0;					// turn off SPI clock
											done   <= 1;					// ensure done is asserted when we hit idle
											cs_pin <= 1'b1;					// release device 
											state  <= tag;
										end else begin 
											bit_cnt <= bit_cnt - 1'b1;
										end
									end
								end
							default:
								begin
								end
						endcase
					end
				STATE_SPI_SEND_2:							// write nibbles from fifo_rptr to fifo_wptr, then if read_cmd switch to reads
					begin
						case(pulse)
							1'd0:							// we put data on the line in the first half cycle
								begin
									if (prev_pulse != pulse) begin
										dout <= temp_bits[7:4];					// in quad mode we shift out the most significant nibble first
										temp_bits <= {temp_bits[3:0], 4'b0};
									end
								end
							1'd1:							// Detect if we should exit from this loop
								begin
									if (prev_pulse != pulse) begin
										// if there are more bytes to send ...
										if (bit_cnt == 1) begin
											if (fifo_rptr < fifo_wptr) begin
												// load next byte from FIFO
												temp_bits	<= fifo[fifo_rptr[$clog2(FIFO_TOTAL_SIZE)-1:0]];
												fifo_rptr	<= fifo_rptr + 1'b1;
												bit_cnt		<= 2;
											end else begin
												// out of bytes we either jump to reading (dummy then payload) or we jump to the tag
												if (doing_read) begin
													bytes_to_read 	<= read_cmd_size + DUMMY_BYTES;
													state			<= STATE_SPI_READ_2;
													bit_cnt 		<= 2;
												end else begin
													busy			<= 0;
													state			<= tag;
												end												
											end
										end else begin
											bit_cnt <= bit_cnt - 1'b1;
										end
									end
								end
							default:
								begin
								end
						endcase
					end
				STATE_SPI_READ_2:							// read from the SPI SRAM upto DUMMY_READ + read_cmd_size bytes
					begin
						case(pulse)
							1'd0:
								begin
									sio_en <= 4'b0000;		// disable all four outputs
								end
							1'd1:							// we sample during the 2nd half of the cycle
								begin
									if (prev_pulse != pulse) begin
										temp_bits <= {temp_bits[3:0], din};				// We read the most significant nibble first so we read/shift at the same time
										if (bit_cnt == 1) begin							// we do the work before checking the counter so we stop at 1 not 0
											// write next byte we read out, this starts just after the cmd and address 
											fifo[fifo_wptr[$clog2(FIFO_TOTAL_SIZE)-1:0]] <= temp_bits;
											fifo_wptr <= fifo_wptr + 1'b1;
											if (bytes_to_read == 1) begin
												// if we only had 1 byte left we're done
												state  <= tag;
												busy   <= 0;
											end else begin
												bit_cnt <= 2;
												bytes_to_read <= bytes_to_read - 1'b1;
											end
										end else begin 
											bit_cnt <= bit_cnt - 1'b1;
										end
									end
								end
							default:
								begin
								end
						endcase
					end
				STATE_IDLE:
					begin
						bauddiv <= quad_bauddiv;								// now we're in QUAD IO mode we can use the potentially faster timing
						if (data_in_valid && fifo_wptr < FIFO_TOTAL_SIZE) begin		// user is writing data to the FIFO to eventually write to SPI SRAM
							// payload goes after the cmd and address
							// note we don't add DUMMY_BYTES here since it's not used in write commands
							// which also means if you write here and then do read_cmd it'll send out a bogus stream confusing the SPI SRAM
							fifo[fifo_wptr[$clog2(FIFO_DEPTH):0]] <= data_in;
							fifo_wptr <= fifo_wptr + 1'b1;
						end else if (data_out_read && (fifo_rptr < read_cmd_wptr)) begin // user is reading from FIFO
							// after a command wptr is after cmd + address + dummy + payload
							// rptr is left to just after cmd + address + dummy
							fifo_rptr <= fifo_rptr + 1'b1;
						end else if (write_cmd == 1 || read_cmd == 1) begin		// user wants to issue a read or write so we prepare the SPI write (command + address + optional payload)
							sio_en 		<= 4'b1111;								// enable all 4 outputs
// we need to form fifo[0..fifo_wptr] which will be 1 byte cmd + SRAM_ADDR_WIDTH/8 bytes of address
							fifo[0]		<= (write_cmd == 1) ? CMD_WRITE : CMD_READ;
							temp_bits 	<= (write_cmd == 1) ? CMD_WRITE : CMD_READ;	// first byte we send has to be in temp_bits and it's the command
							bit_cnt		<= 2;											// reset bit count so we send the full command
							tag 		<= (write_cmd == 1) ? STATE_POST_WRITE : STATE_POST_READ;
							done 		<= 0;											// clear done flag
							fifo_rptr	<= 1;											// reset read pointer so we can send out the command/address/write data if any
							doing_read  <= read_cmd;
							state		<= STATE_STORE_ADDR_1;
						end else begin
							// we're not running a command make sure CS nor busy are not asserted (needed because we get here from INIT_CMD38)
							cs_pin <= 1'b1;
							sio_en <= 4'b0000;	// put pins high impedence
							busy   <= 1'b0;
							done   <= 1'b1;		// ensure done is asserted
						end
					end
				STATE_STORE_ADDR_1:
					begin
						case (SRAM_ADDR_WIDTH)
							'd24: 
								begin
									fifo[1] <= address[23:16];
								end
							'd16:
								begin
									fifo[1] <= address[15:8];
								end
						endcase
						state <= STATE_STORE_ADDR_2;
					end
				STATE_STORE_ADDR_2:
					begin
						case (SRAM_ADDR_WIDTH)
							'd24: 
								begin
									fifo[2] <= address[15:8];
									state <= STATE_STORE_ADDR_3;
								end
							'd16:
								begin
									fifo[2] <= address[7:0];
									state <= STATE_SPI_SEND_2;
									busy 		<= 1;							// start the SPI clock
									cs_pin 		<= 1'b0;
								end
						endcase
					end
				STATE_STORE_ADDR_3:
					begin
						fifo[3]		<= address[7:0];
						state		<= STATE_SPI_SEND_2;
						busy 		<= 1;										// start the SPI clock
						cs_pin		<= 1'b0;
					end
				STATE_POST_WRITE: // after a write command
					begin
						sio_en    <= 4'b0000;									// disable outputs
						busy      <= 0;
						fifo_rptr <= 0;											// reset rptr so we can read it during next submission
						fifo_wptr <= 1 + (SRAM_ADDR_WIDTH/8);					// reset wptr so we can write next command/payload
						state 	  <= STATE_HANGUP;
					end
				STATE_POST_READ: // after a read command
					begin
						busy		  <= 0;
						fifo_rptr	  <= 1 + (SRAM_ADDR_WIDTH/8) + DUMMY_BYTES;	// set to just after command + address + dummy bytes
						fifo_wptr     <= 1 + (SRAM_ADDR_WIDTH/8);
						read_cmd_wptr <= fifo_wptr;
						state		  <= STATE_HANGUP;
					end
				STATE_HANGUP:		// hang up the SPI connection
					begin
						if (cs_pin == 1'b0) begin
							// deassert CS and turn pins to high impedence
							busy			<= 0;					// sure SPI clock stopped
							cs_pin			<= 1'b1;				// put CS pin high
							sio_en			<= 4'b0000;				// turn inout pins to high impedence
							hangup_timer	<= hangup_bauddiv[7:0]; // ensure we hit the required MIN_CPH_NS time (round up for safety)
						end else begin
							if (hangup_timer == 0) begin
								state <= STATE_IDLE;
								done <= 1;
							end else begin
								hangup_timer <= hangup_timer - 1'b1;
							end
						end
					end
				default:
					begin
					end
			endcase
		end
	end
endmodule
