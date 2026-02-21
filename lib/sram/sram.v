`timescale 1ns/1ps

/* Implementation of FIFO based SPI SRAM

We assume the device inits in SPI mode and we need to send it command 0x38 to ender quad mode, then
from there we use command 0x03 to read sequential bytes and 0x02 to write.  We assume sequential
mode is the default (which is on the 23LC512 I'm testing this on).

The design is based on a 1/4 cycle pulse cadence.  The full SPI clock cycle is low
for pulses 0 and 1, and high for pulses 2 and 3.  This means we put data on dout in pulse 1,
and we read data from din on pulse 3.  since our FSM clocks faster than pulses we use prev_pulse
to detect the edge of a pulse.

We technically leave STATE_SPI_SEND_X and STATE_SPI_READ_X early during pulse==3 but since
the next steps sync up to pulse==0 and prev_pulse != pulse they should be fine (that is the 
pulse 3 case for the next FSM state we come from shouldn't trigger).

To write to SRAM

	0.  While busy goto 0.
	1.  Cycle 0: Load the next data into data_in, set data_in_valid
	2.  Cycles 1..N: goto 1.
	3.  cycle N+1: data_in_valid goes low, write_cmd goes high, address is set to the address
	4.  While busy goto 4
	5.  You're done writing.
	
To read SRAM

	0.	While busy goto 0
	1.  Cycle 0: Write read_cmd high, address, and read_cmd_size to the block size you want to read
	2.  Cycles 1..N: While busy goto 2
	3.  Cycle N+1...: Read data_out, set data_out_read high, goto 3 for the rest of the payload (you can use data_out_empty to tell when done easily)
	4.  data_out_read set low

Parameters are setup for 23LC class SPI SRAMs,

for PSRAMs you might need 
	
	DUMMY_BYTES=6 (FAST READ QUAD is the only valid QUAD read command, it has 6 dummy bytes)
	CMD_READ=8'hEB (QUAD FAST READ upto 100MHz usually)
	CMD_EQIO=8'h35 (ENTER QUAD IO mode)

*/

module spi_sram #(
	parameter FIFO_DEPTH=32,								// controls the max burst size
	parameter SRAM_ADDR_WIDTH=16,							// how many bits does the address have (e.g. 16 or 24)
	parameter DUMMY_BYTES=1,								// how many dummy reads are required before the first byte is valid
	parameter CMD_READ=8'h03,								// command to read 
	parameter CMD_WRITE=8'h02,								// command to write
	parameter CMD_EQIO=8'h38								// command to enter quad IO mode
)(
	input clk,												// clock
	input rst_n,											// active low reset

	output reg busy,										// active high means the module is busy with a request
	
	input [7:0] data_in,									// data we want to write to the core
	input data_in_valid,									// active high indicates the user wants to send data to the outgoing FIFO
	output [7:0] data_out,									// assigned fifo[read_ptr]
	input data_out_read,									// active high indicates read_ptr should be incremented
	output data_out_empty,									// active high when all data read from the SPI SRAM is read from the fifo
	
	input write_cmd,										// active high we're doing a write
	input read_cmd,											// active high we're doing a read
	input [$clog2(FIFO_DEPTH):0] read_cmd_size,				// how many bytes the user wants to read
	input [SRAM_ADDR_WIDTH-1:0] address,					// address to read/write from

	inout [3:0] sio_pin,									// data pins
	output reg cs_pin,										// active low CS pin
	output reg sck_pin,										// SPI clock
	input [15:0] bauddiv									// This is clock rate / 4x SPI clock (e.g. lasts 1/4th a full SPI clock).
);

	reg [3:0] dout;											// our output to the SPI bus
	reg [3:0] sio_en;										// per lane output enables 
	
	assign sio_pin[0] = sio_en[0] ? dout[0] : 1'bz;
	assign sio_pin[1] = sio_en[1] ? dout[1] : 1'bz;
	assign sio_pin[2] = sio_en[2] ? dout[2] : 1'bz;
	assign sio_pin[3] = sio_en[3] ? dout[3] : 1'bz;
	wire [3:0] din = sio_pin;
	
	reg [1:0] pulse;										// what part of the 1/4th cycle are we in?
	reg [1:0] prev_pulse;									// previous pulse to detect edge of pulse
	reg [15:0] timer;										// timer to advance pulse
	reg [7:0] fifo[FIFO_DEPTH];								// our SRAM FIFO
	reg [$clog2(FIFO_DEPTH):0] fifo_wptr;					// our SRAM FIFO write pointer (incremented by data_in_valid)
	reg [$clog2(FIFO_DEPTH):0] fifo_rptr;					// our SRAM FIFO read pointer (incremented by data_out_read)
	assign data_out = fifo[fifo_rptr[$clog2(FIFO_DEPTH)-1:0]];	// assign output byte combinatorially	
	assign data_out_empty = (fifo_rptr == fifo_wptr) ? 1'b1 : 1'b0;
	
	reg [4:0] state;										// What state is our FSM in
	reg [4:0] tag;											// return point for sub-states.
	reg [$clog2(DUMMY_BYTES):0] dummy_cnt;					// how many dummy bytes left to discard
	reg [7:0] temp_bits;									// temp bits for single SPI being written or read
	reg [3:0] bit_cnt;										// bit counter for sending initial 0x38 etc
	reg [31:0] temp_addr;
	reg [1:0] temp_addr_idx;
	wire [7:0] temp_addr_byte;
	assign temp_addr_byte = (temp_addr_idx == 3) ? temp_addr[31:24] :
								(temp_addr_idx == 2) ? temp_addr[23:16] :
									(temp_addr_idx == 1) ? temp_addr[15:8] :
										(temp_addr_idx == 0) ? temp_addr[7:0] : 8'd0;

	// the SPI pulses FSM
	always @(posedge clk) begin
		if (!rst_n) begin
			timer <= bauddiv;
			pulse <= 0;
			prev_pulse <= 2'd3;								// init prev to 3 so the first pass detects the edge if needed
		end else begin
			if (busy) begin									// only run SPI pulses if the module is busy
				prev_pulse <= pulse;						// latch previous value of pulse
				if (timer > 0) begin
					timer <= timer - 1'b1;
				end else begin
					pulse <= pulse + 1'b1;					// advance pulse 4 times per SPI clk
					timer <= bauddiv;
					sck_pin <= ((pulse == 1 || pulse == 2) ? 1'b1 : 1'b0);	// SCK is high during the last half of the clock
				end
			end else begin
				// we're idle so reset pulse
				timer <= bauddiv;
				pulse <= 0;
				prev_pulse <= 2'd3;
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
		STATE_START_WRITE=5,
		STATE_WRITE_ADDR=6,
		STATE_WRITE_DATA=7,
		STATE_START_READ=8,
		STATE_READ_ADDR=9,
		STATE_READ_DATA=10,
		STATE_HANGUP=11,
		STATE_CMD_START_DELAY=12,
		STATE_INIT_CMD_EQIO=13;

	always @(posedge clk) begin
		if (!rst_n) begin
			fifo_wptr <= 0;
			fifo_rptr <= 0;
			state <= STATE_INIT;
			dummy_cnt <= DUMMY_BYTES;
			temp_bits <= 0;
			bit_cnt <= 0;
			sio_en <= 4'b0000;								// disable all outputs
			cs_pin <= 1'b1;									// ensure chip isn't selected
			dout <= 0;
			busy <= 1;
			temp_addr <= 0;
			temp_addr_idx <= 0;
		end else begin
			case(state)
				STATE_CMD_START_DELAY:
					begin
						if (prev_pulse != pulse && pulse == 3) begin
							if (bit_cnt == 0) begin
								state <= tag;
							end else begin
								bit_cnt <= bit_cnt - 1;
							end
						end
					end
				STATE_INIT:
					begin
						// prepare to send SPI command 0x38 to enter quad mode
						cs_pin <= 1'b0;						// assert CS to wake the device
						bit_cnt <= 1;						// wait one SPI cycle before sending the initializing command
						state <= STATE_CMD_START_DELAY;
						tag <= STATE_INIT_CMD_EQIO;
					end
				STATE_INIT_CMD_EQIO:
					begin
						temp_bits <= CMD_EQIO;				// enter quad mode
						bit_cnt <= 8;						// 8 bits to send
						state <= STATE_SPI_SEND_8;
						tag <= STATE_IDLE;
					end
				STATE_SPI_SEND_8:							// send 8 bits in temp_bits (sio_en[0] = 1, bit_cnt = 8)	
					begin
						case(pulse)
							2'd0:
								begin
									sio_en <= 4'b0001;		// enable only MISO as output
								end
							2'd1:							// we put data on the line mid way through the first half cycle
								begin
									if (prev_pulse != pulse) begin
										// this FSM state will be reached many times with pulse==1 so we only process
										// the state on the leading edge of this pulse
										dout[0] <= temp_bits[7];
										temp_bits <= {temp_bits[6:0], 1'b0};
									end
								end
							2'd3:							// Detect if we should exit this loop
								begin
									if (prev_pulse != pulse) begin
										// this FSM state will be reached many times with pulse==3 so we only process
										// the state on the leading edge of this pulse
										if (bit_cnt == 0) begin
											sio_en <= 4'b0000;				// done sending disable outputs		
											state <= tag;
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
				STATE_SPI_SEND_2:							// send 2 nibbles in temp_bits (sio_en = 4'b1111, bit_cnt = 2)
					begin
						case(pulse)
							2'd0:
								begin
									sio_en <= 4'b1111;		// enable all four outputs
								end
							2'd1:							// we put data on the line mid way through the first half cycle
								begin
									if (prev_pulse != pulse) begin
										// this FSM state will be reached many times with pulse==1 so we only process
										// the state on the leading edge of this pulse
										dout <= temp_bits[7:4];
										temp_bits <= {temp_bits[3:0], 4'b0};
									end
								end
							2'd3:							// Detect if we should exit from this loop
								begin
									if (prev_pulse != pulse) begin
										// we handle jumping to the next state when we enter pulse==3 that way if we're READING after this there is no collision
										if (bit_cnt == 0) begin
											sio_en <= 4'b0000;				// done sending disable outputs		
											state <= tag;
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
				STATE_SPI_READ_2:							// read 2 nibbles into temp_bits (sio_en = 4'b1111, bit_cnt = 2)
					begin
						case(pulse)
							2'd0:
								begin
									sio_en <= 4'b0000;		// disable all four outputs
								end
							2'd3:							// we sample halfway through the 2nd half of the cycle
								begin
									if (prev_pulse != pulse) begin
										// this FSM state will be reached many times with pulse==3 so we only process
										// the state on the leading edge of this pulse
										temp_bits <= {temp_bits[3:0], din};
										if (bit_cnt == 0) begin
											state <= tag;
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
						if (data_in_valid && fifo_wptr < FIFO_DEPTH) begin
							fifo[fifo_wptr[$clog2(FIFO_DEPTH)-1:0]] <= data_in;
							fifo_wptr <= fifo_wptr + 1'b1;
						end
						if (data_out_read && fifo_rptr < fifo_wptr) begin
							fifo_rptr <= fifo_rptr + 1'b1;
						end
						if (write_cmd == 1 || read_cmd == 1) begin
							cs_pin <= 1'b0;										// lower CS pin to select chip
							temp_addr[SRAM_ADDR_WIDTH-1:0] <= address;			// store the address being accessed
							temp_addr_idx <= 2'((SRAM_ADDR_WIDTH/8) - 1); 		// start at the most sig byte
							busy <= 1;											// we're now busy
							bit_cnt <= 1; 										// 1 SPI cycle wait before sending command and/or data
							state <= STATE_CMD_START_DELAY;
							if (write_cmd == 1) begin
								// writing
								tag <= STATE_START_WRITE;
								fifo_rptr <= 0;										// ensure we start at the beginning of the FIFO (upto fifo_wptr)
							end else begin
								// reading (implied)
								tag <= STATE_START_READ;
							end
						end else begin
							// we're not running a command make sure CS nor busy are not asserted (needed because we get here from INIT_CMD38)
							cs_pin <= 1'b1;
							sio_en <= 4'b0000; // put pins high impedence
							busy   <= 1'b0;
						end
					end
				STATE_START_WRITE:	// start a write command
					begin
						// send write command
						temp_bits <= CMD_WRITE;
						bit_cnt <= 2;
						state <= STATE_SPI_SEND_2;
						tag <= STATE_WRITE_ADDR;
						fifo_rptr <= 0;
					end
				STATE_WRITE_ADDR:	// loop that sends the WRITE address 
					begin
						temp_bits <= temp_addr_byte;
						temp_addr_idx <= temp_addr_idx - 1'b1;
						state <= STATE_SPI_SEND_2;
						tag <= (temp_addr_idx > 0) ? STATE_WRITE_ADDR : STATE_WRITE_DATA;
					end
				STATE_WRITE_DATA:	// loop that transmits the FIFO over SPI
					begin
						if (fifo_rptr < fifo_wptr) begin
							temp_bits <= fifo[fifo_rptr[$clog2(FIFO_DEPTH)-1:0]];
							fifo_rptr <= fifo_rptr + 1'b1;
							tag <= STATE_WRITE_DATA;
							state <= STATE_SPI_SEND_2;
							bit_cnt <= 2;
						end else begin
							state <= STATE_HANGUP;
							fifo_wptr <= 0;					// reset write pointer so new data can be written in
						end
					end
				STATE_START_READ:	// start a READ command
					begin
						// send read command
						temp_bits <= CMD_READ;
						bit_cnt <= 2;
						state <= STATE_SPI_SEND_2;
						tag <= STATE_READ_ADDR;
					end
				STATE_READ_ADDR:	// loop that sends the READ address
					begin
						temp_bits <= temp_addr_byte;
						temp_addr_idx <= temp_addr_idx - 1'b1;
						if (temp_addr_idx > 0) begin
							state <= STATE_SPI_SEND_2;
							tag <= STATE_READ_ADDR;
						end else begin
							state <= STATE_SPI_READ_2;
							tag <= STATE_READ_DATA;
							bit_cnt <= 2;
							dummy_cnt <= DUMMY_BYTES;	// read dummy bytes
						end
					end
				STATE_READ_DATA:	// loop that fills FIFO with data from SPI SRAM
					begin
						if (dummy_cnt == 0) begin
							fifo[fifo_wptr[$clog2(FIFO_DEPTH)-1:0]] <= temp_bits;
							fifo_wptr <= fifo_wptr + 1;
							if (fifo_wptr < read_cmd_size - 1) begin  // more data?
								bit_cnt <= 2;
								state <= STATE_SPI_READ_2;
								tag <= STATE_READ_DATA;
							end else begin
								state <= STATE_HANGUP;
								fifo_rptr <= 0;						// Ensure rptr is zero so we can read this out 
							end
						end else begin
							// decrease amount of dummy read cycles
							dummy_cnt <= dummy_cnt - 1'b1;
							bit_cnt <= 2;
							state <= STATE_SPI_READ_2;				// read another byte
							tag <= STATE_READ_DATA;
						end
					end
				STATE_HANGUP:		// hang up the SPI connection
					begin
						if (cs_pin == 1'b0) begin
							// deassert CS and turn pins to high impedence
							cs_pin <= 1'b1;					// put CS pin high
							sio_en <= 4'b0000;				// turn inout pins to high impedence
							bit_cnt <= 2;					// delay two SPI cycles to let device refresh (preparing for PSRAM...)
						end else begin
							if (prev_pulse != pulse && pulse == 3) begin
								if (bit_cnt == 0) begin
									state <= STATE_IDLE;
									busy <= 0;
								end else begin
									bit_cnt <= bit_cnt - 1;
								end
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
