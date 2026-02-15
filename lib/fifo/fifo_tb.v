`timescale 1ns/1ps

module fifo_tb();
	reg clk;
	reg rst_n;
	
	reg write;
	reg [7:0] data_in;
	reg read;
	wire [7:0] data_out;
	
	wire empty;
	wire full;
	reg flush;
	
	reg [3:0] state;
	
	localparam
		DEPTH=4;
	
	fifo #(.FIFO_DEPTH(DEPTH), .DATA_WIDTH(8)) fifo_dut(
		.clk(clk), .rst_n(rst_n),
		.write(write), .data_in(data_in),
		.read(read), .data_out(data_out),
		.empty(empty), .full(full),
		.flush(flush));

    // Parameters for the simulation
    localparam CLK_PERIOD = 20; // 50MHz Clock
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;
    
    integer i;
	
	initial begin
        // Waveform setup
        $dumpfile("fifo.vcd");
        $dumpvars(0, fifo_tb);
		clk = 0;
		rst_n = 0;
		write = 0;
		read = 0;
		data_in = 0;
		flush = 0;
		state = 0;

        // Reset system
        repeat(3) @(posedge clk);
        rst_n = 1;
		@(posedge clk);
		expect_state(0, 1, 0);			// reset so we expect !full, empty, !cnt
		
		// write AA into FIFO
		state = 1;
		$display("Starting phase: %d", state);
		data_in = 8'hAA;
		write = 1;
		@(posedge clk);
		write = 0;						// clear write
		@(posedge clk);
		expect_state(0, 0, 1);			// reset so we expect !full, !empty, cnt == 1
		
		// read it out
		state = 2;
		$display("Starting phase: %d", state);
		read = 1;
		@(posedge clk);
		read = 0;
		@(posedge clk);
		expect_state(0, 1, 0);			// reset so we expect !full, empty, !cnt
		expect_dout(8'hAA);
		
		// fill fifo depth
		state = 3;
		$display("Starting phase: %d", state);
		for (i = 0; i < DEPTH; i++) begin
			data_in = 8'hC0 + i[7:0];
			write = 1;
			@(posedge clk);
			write = 0;						// clear write
			@(posedge clk);
			expect_state(i == (DEPTH - 1) ? 1 : 0, 0, i[2:0] + 3'b1);
		end		

		// read it out
		state = 4;
		$display("Starting phase: %d", state);
		for (i = 0; i < DEPTH; i++) begin
			read = 1;
			@(posedge clk);
			read = 0;
			@(posedge clk);
			expect_state(0, i == (DEPTH - 1) ? 1 : 0, DEPTH[2:0] - i[2:0] - 3'b1);
			expect_dout((8'hC0 + i[7:0]));
		end
		expect_state(0, 1, 0);
		
		// read write to empty state
		state = 5;
		$display("Starting phase: %d", state);
		data_in = 8'hD0;
		read = 1;
		write = 1;
		@(posedge clk);
		read = 0;
		write = 0;
		@(posedge clk);
		expect_state(0, 1, 0);
		expect_dout(8'hD0);
		
		// offset read write, first write E0, then read E0/write E1, then read E1
		state = 6;
		$display("Starting phase: %d", state);
		// cycle 1 initiate write
			read = 0;
			write = 1;				// first write
			data_in = 8'hE0;
			@(posedge clk);
		// cycle 2: initiate read
			read = 1;				// initiate read
			write = 0;
			@(posedge clk);
		// cycle 3: initiate write of E1
			data_in = 8'hE1;
			read = 0;
			write = 1;
			@(posedge clk);
			expect_dout(8'hE0);		// should have first read back now
		// cycle 4: initiate read
			read = 1;
			write = 0;
			@(posedge clk);
		// cycle 5: idle
			read = 0;
			write = 0;
			@(posedge clk);
			expect_dout(8'hE1);		// should have 2nd read back now
			expect_state(0, 1, 0); // should be idle
		$finish;
	end

	task expect_dout(input [7:0] dout);
		begin
			if (data_out != dout) begin
				$display("ASSERTION FAILED:  Was expecting data_out to be %2h not %2h", dout, data_out);
				repeat(16) @(posedge clk);
				$fatal;
			end
		end
	endtask		
		
	task expect_state(input efull, input eempty, input [2:0] ecnt);
		begin
			if (full != efull) begin
				$display("ASSERTION FAILED:  Was expecting full to be %d", efull);
				repeat(16) @(posedge clk);
				$fatal;
			end
			if (empty != eempty) begin
				$display("ASSERTION FAILED:  Was expecting empty to be %d", eempty);
				repeat(16) @(posedge clk);
				$fatal;
			end
			if (ecnt != fifo_dut.FIFO_CNT) begin
				$display("ASSERTION FAILED:  Was expecting FIFO_CNT  to be %d not %d", ecnt, fifo_dut.FIFO_CNT);
				repeat(16) @(posedge clk);
				$fatal;
			end
		end
	endtask
endmodule    
