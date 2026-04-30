`timescale 1ns/1ps

/*
Simple parallel access full duplex FIFO.  Supports
flushing, signals full/empty, handles precendence order of 

- Flush (inc. simultaneous write)
- Reads and Writes
- Writes
- Reads

Uses registers for storage.
*/

// if verifying use a non-power of 2 depth to test proper modulo math
`ifdef FORMAL
`define DEFAULT_DEPTH 7
`else
`define DEFAULT_DEPTH 4
`endif

module fifo
#(parameter
	FIFO_DEPTH=`DEFAULT_DEPTH,
	DATA_WIDTH=8
)(
	input wire clk,
	input wire rst_n,
	
	input wire write,							// latch data_in on posedge of write
	input wire [DATA_WIDTH-1:0] data_in,

	input wire read,
	output reg [DATA_WIDTH-1:0] data_out,	// register data_out on posedge of read
	
	output wire empty,
	output wire full,
	
	input wire flush								// zero out the fifo on posedge of flush
);

	reg [DATA_WIDTH-1:0] FIFO[FIFO_DEPTH-1:0];
	reg [$clog2(FIFO_DEPTH):0] FIFO_WPTR;
	reg [$clog2(FIFO_DEPTH):0] FIFO_RPTR;
	reg [$clog2(FIFO_DEPTH):0] FIFO_CNT;
	
	assign empty = (rst_n & FIFO_CNT == 0);
	assign full = (rst_n & FIFO_CNT == FIFO_DEPTH);
	
	wire want_read  = (rst_n & (read && (!empty || write)));
	wire want_write = (rst_n & (write && (!full || read)));
	wire want_flush = (rst_n & (flush));
	
	always @(*) begin
		data_out = 0;
		if ((FIFO_CNT == 0 || want_flush) && want_write && want_read) begin
			data_out = data_in;
		end else begin
			data_out = FIFO[FIFO_RPTR[$clog2(FIFO_DEPTH)-1:0]];
		end
	end

	always @(posedge clk) begin
		if (!rst_n) begin
			FIFO_WPTR	<= 0;
			FIFO_RPTR	<= 0;
			FIFO_CNT	<= 0;
		end else begin
			// priority is flush, then read&write, then write, then read
			if (want_flush) begin
				// read and writing and flushing?
				if (want_write && want_read) begin
					FIFO_WPTR	<= 0;
					FIFO_RPTR	<= 0;
					FIFO_CNT	<= 0;
					FIFO[0] 	<= data_in;
				end else if (want_write) begin 	// only writing
					// we want flush and write so jam the first entry in
					FIFO[0]		<= data_in;
					FIFO_WPTR	<= 'b1;
					FIFO_RPTR	<= 0;
					FIFO_CNT	<= 'b1;
				end else begin
					FIFO_WPTR	<= 0;
					FIFO_RPTR	<= 0;
					FIFO_CNT	<= 0;
				end
			end else if (want_write && want_read) begin
				// we're doing both
				if (FIFO_CNT == 0) begin
					// FIFO is empty just blast it out
					FIFO[FIFO_WPTR[$clog2(FIFO_DEPTH)-1:0]] <= data_in;
				end else begin
					// FIFO isn't empty so read and write from respective spots
					if (FIFO_RPTR == FIFO_DEPTH - 1'b1) begin
						FIFO_RPTR <= 0;
					end else begin
						FIFO_RPTR <= FIFO_RPTR + 1'b1;
					end
					FIFO[FIFO_WPTR[$clog2(FIFO_DEPTH)-1:0]] <= data_in;
					if (FIFO_WPTR == FIFO_DEPTH - 1'b1) begin
						FIFO_WPTR <= 0;
					end else begin
						FIFO_WPTR <= FIFO_WPTR + 1'b1;
					end
				end
				// no change to CNT
			end else if (want_write && FIFO_CNT != FIFO_DEPTH) begin
				FIFO[FIFO_WPTR[$clog2(FIFO_DEPTH)-1:0]] <= data_in;
				if (FIFO_WPTR == FIFO_DEPTH - 1'b1) begin
					FIFO_WPTR <= 0;
				end else begin
					FIFO_WPTR <= FIFO_WPTR + 1'b1;
				end
				FIFO_CNT      <= FIFO_CNT + 1'b1;
			end else if (want_read && FIFO_CNT > 0) begin
				if (FIFO_RPTR == FIFO_DEPTH - 1'b1) begin
					FIFO_RPTR <= 0;
				end else begin
					FIFO_RPTR <= FIFO_RPTR + 1'b1;
				end
				FIFO_CNT	<= FIFO_CNT - 'b1;
			end
		end
	end
			
`ifdef FORMAL
	initial assume(!rst_n);

	// 2. Fundamental FIFO Invariants
	always @(*) begin
		if (rst_n) begin
			// The count should never exceed the depth
			assert(FIFO_CNT <= FIFO_DEPTH);
			
			// Zero or full count should have equal ptr
			assert((!FIFO_CNT || FIFO_CNT == FIFO_DEPTH) ? (FIFO_RPTR == FIFO_WPTR) : (FIFO_RPTR != FIFO_WPTR));
				
			// FIFO_CNT + FIFO_RPTR (mod FIFO_DEPTH) == FIFO_WPTR
			assert(((FIFO_CNT + FIFO_RPTR) % FIFO_DEPTH) == FIFO_WPTR);
			
			// Empty/Full flag consistency
			assert(empty == (FIFO_CNT == 0));
			assert(full == (FIFO_CNT == FIFO_DEPTH));
		end
	end

	// 3. Pointer checks
	// Ensure pointers wrap correctly or stay within bounds
	always @(*) begin
		if (rst_n) begin
			assert(FIFO_WPTR < FIFO_DEPTH);
			assert(FIFO_RPTR < FIFO_DEPTH);
		end
	end
	
	// 4. data check
	reg data_wrote_flag = 0;
	reg data_read_flag = 0;
	reg [DATA_WIDTH-1:0] data_wrote = 0; 
	always @(posedge clk) begin
		if (rst_n) begin			
			// constrain signals to sensible conditions
			assume(!want_read || (want_read && (!empty || want_write)));
			assume(!want_write || (want_write && (!full || want_write || want_flush)));
			assume(!want_flush || (want_flush && (!empty || want_write)));
									
			if ($past(want_flush)) begin
				// on a flush we either store a write or bypass it to a read
				data_wrote_flag <= 0;
				data_read_flag <= 0;
				if (!$past(want_read) && $past(want_write)) begin
					// no read but we have a write
					data_wrote_flag <= 1;
					data_read_flag <= 0;
					data_wrote <= $past(data_in);
					
					assert(FIFO[0] == $past(data_in));
					assert(FIFO_RPTR == 0);
					assert(FIFO_WPTR == 1);
					assert(FIFO_CNT == 1);
				end
				if ($past(want_read) && $past(want_write)) begin
					// read and write so we bypass
					assert(data_out == $past(data_in));
					assert(FIFO_RPTR == 0);
					assert(FIFO_WPTR == 0);
					assert(FIFO_CNT == 0);
				end
				if (!$past(want_read) && !$past(want_write)) begin
					assert(FIFO_RPTR == 0);
					assert(FIFO_WPTR == 0);
					assert(FIFO_CNT == 0);
				end
			end else begin
				if ((!data_wrote_flag || $past(want_flush)) && !data_read_flag && $past(want_write) && $past(want_read)) begin
					// doing a read + write, so we either bypass write or fetch first written data
					data_read_flag <= 1;
					assert(data_out == (data_wrote_flag ? data_wrote : $past(data_in)));
					if (FIFO_CNT) begin
						//assert(data_out == FIFO[$past(FIFO_RPTR)]);
					end
				end else if (!data_wrote_flag && !data_read_flag && $past(want_write)) begin
					// we're empty empty so store the first write
					data_wrote_flag <= 1;
					data_wrote      <= $past(data_in);
					assert(!empty);
				end else if (data_wrote_flag && !data_read_flag && $past(want_read)) begin
					// read data read in previous cycle
					assert(data_out == data_wrote);
					assert(data_out == FIFO[$past(FIFO_RPTR)]);
					data_read_flag  <= 1;
				end
			end
		end else begin
			data_wrote_flag <= 0;
			data_read_flag <= 0;
		end
	end
`endif
endmodule
