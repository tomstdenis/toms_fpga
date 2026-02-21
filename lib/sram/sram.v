`timescale 1ns/1ps

/* Implementation of FIFO based SPI SRAM

We assume the device inits in SPI mode and we need to send it command 0x38 to ender quad mode, then
from there we use command 0x03 to read sequential bytes and 0x02 to write.  We assume sequential
mode is the default (which is on the 23LC512 I'm testing this on).



*/

module spi_sram #(
	parameter FIFO_DEPTH=32,								// controls the max burst size
	parameter SRAM_ADDR_WIDTH=16,							// how many bits does the address have (e.g. 16 or 24)
	parameter DUMMY_BYTES=1,								// how many dummy reads are required before the first byte is valid
)(
	input clk,												// clock
	input rst_n,											// active low reset
	
	input [7:0] data_in,									// data we want to write to the core
	input data_in_valid,									// active high indicates the user wants to send data to the outgoing FIFO
	output [7:0] data_out,									// assigned fifo[read_ptr]
	input data_out_read,									// active high indicates read_ptr should be incremented
	
	input write_cmd,										// active high we're doing a write
	input read_cmd,											// active high we're doing a read
	input [$clog2(FIFO_DEPTH):0] read_cmd_size,				// how many bytes the user wants to read
	input [$clog2(SRAM_ADDR_WIDTH)-1:0] address,			// address to read/write from

	inout [3:0] sio_pin,									// data pins
	output reg cs_pin,										// active low CS pin
	output reg sck_pin,										// SPI clock
	input [15:0] bauddiv;									// This is clock rate / 4x SPI clock (e.g. lasts 1/4th a full SPI clock).
);
	reg [3:0] dout;											// our output to the SPI bus
	reg [3:0] sio_en;										// per lane output enables 
	
	assign sio_pin[0] = sio_en[0] ? dout[0] : 1'bz;
	assign sio_pin[1] = sio_en[1] ? dout[1] : 1'bz;
	assign sio_pin[2] = sio_en[2] ? dout[2] : 1'bz;
	assign sio_pin[3] = sio_en[3] ? dout[3] : 1'bz;
	wire [3:0] din = sio_pin;
	
	reg [1:0] pulse;										// what part of the 1/4th cycle are we in?
	reg [15:0] timer;										// timer to advance pulse
	reg [7:0] fifo[FIFO_DEPTH];								// our SRAM FIFO
	reg [$clog2(FIFO_DEPTH):0] fifo_wptr;					// our SRAM FIFO write pointer (incremented by data_in_valid)
	reg [$clog2(FIFO_DEPTH):0] fifo_rptr;					// our SRAM FIFO read pointer (incremented by data_out_read)
	assign data_out = fifo[fifo_rptr];						// assign output byte	
	
	reg [4:0] state;										// What state is our FSM in
	reg [4:0] tag;											// return point for sub-states.
	reg [$clog2(DUMMY_BYTES):0] dummy_cnt;					// how many dummy bytes left to discard
	reg [7:0] temp_bits;									// temp bits for single SPI being written or read
	reg [2:0] bit_cnt;										// bit counter for sending initial 0x38 etc
	reg [7:0] temp_nibs;									// temp nibs for quad SPI
	reg [31:0] temp_addr;
	reg [1:0] temp_addr_idx;
	wire [7:0] temp_addr_byte;
	
	always @(*) begin
		case (temp_addr_idx)
			2'd3: temp_addr_byte = temp_addr[31:24];
			2'd2: temp_addr_byte = temp_addr[23:16];
			2'd1: temp_addr_byte = temp_addr[15:8];
			2'd0: temp_addr_byte = temp_addr[7:0];
		endcase
	end

	// the SPI pulses FSM
	always @(posedge clk) begin
		if (!rst_n) begin
			timer <= bauddiv;
			pulse <= 0;
		end else begin
			if (state != STATE_IDLE && state != STATE_INIT) begin
				if (timer) begin
					timer <= timer - 1'b1;
				end else begin
					pulse <= pulse + 1'b1;					// advance pulse 4 times per SPI clk
					timer <= bauddiv;
					sck_pin <= (pulse >= 2 ? 1'b1 : 1'b0);	// SCK is high during the last half of the clock
					if (pulse == 1) begin					// shift temp after sending in pulse 2
						temp_bits <= {temp_bits[6:0], 1'b0};	// shift left only when switching to pulse==1
						temp_bibs <= {temp_nibs[3:0], 4'b0};	// shift nibs left 4 for quad mode
						bit_cnt <= bit_cnt - 1'b1;
					end
				end
			end else begin
				// we're idle so reset pulse
				timer <= bauddiv;
				pulse <= 0;
			end
		end
	end
	
	localparam
		STATE_INIT=0,
		STATE_IDLE=1,
		STATE_SPI_SEND_8=2,
		STATE_SPI_SEND_2=3,

	always @(posedge clk) begin
		if (!rst_n) begin
			fifo_wptr <= 0;
			fifo_rptr <= 0;
			state <= STATE_INIT;
			dummy_cnt <= DUMMY_BYTES;
			temp_byte <= 0;
			bit_cnt <= 0;
			sio_en <= 4'b0000;								// disable all outputs
			dout <= 0;
		end else begin
			case(state)
				STATE_INIT:
					begin
						// prepare to send SPI command 0x38 to enter quad mode
						temp_byte <= 8'h38;					// enter quad mode
						bit_cnt <= 8;						// 8 bits to send
						state <= STATE_SPI_SEND_8;
						tag <= STATE_IDLE;
						sio_en <= 4'b0001;					// enable output on MOSI sio[0]
					end
				STATE_SPI_SEND_8:							// send 8 bits in temp_bits (sio_en[0] = 1, bit_cnt = 8)	
					begin
						// we send on pulse==01
						if (pulse == 2'd1) begin
							dout[0] <= temp_bits[7];				// output MSB
						end
						if (pulse == 2'd3) begin
							if (bit_cnt == 0) begin
								state <= tag;
							end
						end
					end
				STATE_SPI_SEND_2:							// send 2 nibs in temp_nibs (sio_en = 4'b1111, bit_cnt = 2)
					begin
						// we send on pulse==01
						if (pulse == 2'd1) begin
							dout <= temp_nibs[7:4];			// send the top nibble first
						end
						if (pulse == 2'd3) begin
							if (bit_cnt == 0) begin
								state <= tag;
							end
						end
				STATE_IDLE:
					begin
						if (data_in_valid && fifo_wptr < FIFO_DEPTH) begin
							fifo[fifo_wptr] <= data_in;
							fifo_wptr <= fifo_wptr + 1'b1;
						end
						if (data_out_read && fifo_rptr < read_cmd_size) begin
							fifo_rptr <= fifo_rptr + 1'b1;
						end
						if (write_cmd == 1) begin
							state <= STATE_START_WRITE;
							cs_pin <= 1'b0;
							sio_en <= 4'b1111;
							temp_addr <= { 'b0, address };
						end else if (read_cmd == 1) begin
							state <= STATE_START_READ;
							cs_pin <= 1'b0;
							sio_en <= 4'b1111;
							temp_addr <= { 'b0, address };
							temp_addr_idx <= (ADDR_WIDTH/8) - 1;
						end
					end
				STATE_START_WRITE:
					begin
						// send byte 0x02
						temp_nibs <= 8'h02;
						bit_cnt <= 2;
						state <= STATE_SPI_SEND_2;
						tag <= STATE_WRITE_ADDR;
						fifo_rptr <= 0;
					end
				STATE_WRITE_ADDR:
					begin
						temp_nibs <= temp_addr_byte;
						tmp_addr_idx <= tmp_addr_idx - 1'b1;
						state <= STATE_SPI_SEND_2;
						tag <= (temp_addr_idx > 0) ? STATE_SEND_ADDR : STATE_WRITE_DATA;
					end
				STATE_WRITE_DATA:
					begin
						if (fifo_rptr < fifo_wptr) begin
							temp_nibs <= fifo[fifo_rptr];
							fifo_rptr <= fifo_rptr + 1'b1
							tag <= STATE_WRITE_DATA;
							state <= STATE_SPI_SEND_2;
							bit_cnt <= 2;
						end else begin
							state <= STATE_HANGUP;
						end
				STATE_START_READ:
					begin
						fifo_wptr <= 0;
					end
				STATE_HANGUP:
					begin
						cs_pin <= 1'b1;					// put CS pin high
						sio_en <= 4'b0000;				// turn inout pins to high impedence
						fifo_rptr <= 0;
						fifo_wptr <= 0;
						state <= STATE_IDLE;
					end
				default:
					begin
					end
			endcase
		end
	end
endmodule
