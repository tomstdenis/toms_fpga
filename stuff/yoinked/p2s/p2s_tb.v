`timescale 1ns/1ps

module p2s_tb();
    reg clk;
    reg rst_n;
    
    reg valid_in;
    reg [7:0] data_in;
    wire valid_out;
    wire data_out;
    
	p2s dut_p2s(
		.clk(clk),
		.reset(~rst_n),
		.valid_in(valid_in),
		.data_in(data_in),
		.valid_out(valid_out),
		.data_out(data_out));

    // Parameters
    localparam CLK_PERIOD = 20;		// 50MHz

    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Test Logic ---
    integer i;
    
    initial begin
        // Waveform setup
        $dumpfile("p2s_tb.vcd");
        $dumpvars(0, p2s_tb);

        // Initialize
        clk = 0;
        rst_n = 0;
        valid_in = 0;

        // Reset system
        @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        $display("Sending 0xA5...");
        @(posedge clk);
        valid_in = 1'b1;
        data_in  = 8'hA5;
        @(posedge clk);
        valid_in = 1'b0;
        wait(valid_out == 1); // wait for it to go high
        i = 0;
        while (valid_out == 1) begin // then wait for it to go low (doing a fork here with timeout is a good idea)
			i = i + 1;
			if (i == 100) begin
				$display("timed out waiting for valid_out to go low...");
				$fatal;
			end
			@(posedge clk);
		end
        $finish;
    end
endmodule
