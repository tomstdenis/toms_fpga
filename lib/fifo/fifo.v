`timescale 1ns/1ps

module fifo
#(parameter
	FIFO_DEPTH=4,
	DATA_WIDTH=8
)(
	input clk,
	input rst_n,
	
	input write,							// latch data_in on posedge of write
	input [DATA_WIDTH-1:0] data_in,

	input read,
	output reg [DATA_WIDTH-1:0] data_out,	// register data_out on posedge of read
	
	output empty,
	output full,
	
	input flush								// zero out the fifo on posedge of flush
);

	reg [DATA_WIDTH-1:0] FIFO[FIFO_DEPTH-1:0];
	reg [$clog2(FIFO_DEPTH)-1:0] FIFO_WPTR;
	reg [$clog2(FIFO_DEPTH)-1:0] FIFO_RPTR;
	reg [$clog2(FIFO_DEPTH):0] FIFO_CNT;
	
	assign empty = (rst_n & FIFO_CNT == 0);
	assign full = (rst_n & FIFO_CNT == FIFO_DEPTH);
	
	wire want_read  = (rst_n & (read && (!empty || write)));
	wire want_write = (rst_n & (write && (!full || read)));
	wire want_flush = (rst_n & (flush));
	
	integer i;
	
	always @(posedge clk) begin
		if (!rst_n) begin
			FIFO_WPTR <= 0;
			FIFO_RPTR <= 0;
			FIFO_CNT <= 0;
			for (i = 0; i < FIFO_DEPTH; i++) begin
				FIFO[i] <= 0;
			end
			data_out <= 0;
		end else begin
			// priority is flush, then read&write, then write, then read
			if (want_flush) begin
				// are we also writing?
				if (want_write) begin
					// we want flush and write so jam the first entry in
					FIFO[0] <= data_in;
					FIFO_WPTR <= 'b1;
					FIFO_RPTR <= 0;
					FIFO_CNT <= 'b1;
				end else begin
					FIFO_WPTR <= 0;
					FIFO_RPTR <= 0;
					FIFO_CNT <= 0;
				end
			end else if (want_write && want_read) begin
				// we're doing both
				if (FIFO_CNT == 0) begin
					// FIFO is empty just blast it out
					data_out <= data_in;
				end else begin
					// FIFO isn't empty so read and write from respective spots
					data_out <= FIFO[FIFO_RPTR];
					FIFO_RPTR <= FIFO_RPTR + 'b1;
					FIFO[FIFO_WPTR] <= data_in;
					FIFO_WPTR <= FIFO_WPTR + 'b1;
				end
				// no change to CNT
			end else if (want_write && FIFO_CNT != FIFO_DEPTH) begin
				FIFO[FIFO_WPTR] <= data_in;
				FIFO_WPTR <= FIFO_WPTR + 'b1;
				FIFO_CNT <= FIFO_CNT + 'b1;
			end else if (want_read && FIFO_CNT > 0) begin
				data_out <= FIFO[FIFO_RPTR];
				FIFO_RPTR <= FIFO_RPTR + 'b1;
				FIFO_CNT <= FIFO_CNT - 'b1;
			end
		end
	end				
endmodule
