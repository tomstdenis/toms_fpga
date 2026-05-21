`timescale 1ns/1ps

module sqrt_bin_tb();
	reg clk;
	reg rst_n;

	localparam
		BIT_WIDTH=16;
		
	reg [BIT_WIDTH-1:0] num;
	reg valid;
	
	wire [(BIT_WIDTH/2)-1:0] sqrt;
	wire ready;
	
	sqrt_bin #(.BIT_WIDTH(BIT_WIDTH)) sqrty (
		.clk(clk),
		.rst_n(rst_n),
		.num(num), .valid(valid),
		.ready(ready), .sqrt(sqrt));

    // Parameters for the simulation
    localparam CLK_PERIOD = 20; // 50MHz Clock
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;
    
    integer i;
	
	initial begin
        // Waveform setup
        $dumpfile("sqrt_bin.vcd");
        $dumpvars(0, sqrt_bin_tb);
		clk = 0;
		valid = 0;
		num = 0;

        // Reset system
        repeat(3) @(posedge clk);
        rst_n = 1;
		@(posedge clk); #1;
				
		for (i = 0; i < (1<<BIT_WIDTH); i = i + 1) begin
/* verilator lint_off WIDTHTRUNC */
			num = i; // $urandom_range(0, ((1<<BIT_WIDTH)-1));
/* verilator lint_on WIDTHTRUNC */
			valid = 1;
			wait(ready == 1); #1;
			valid = 0;
			@(posedge clk); #1;
			$display("n=%x s=%x", num, sqrt);
/* verilator lint_off WIDTHEXPAND */
			if (!(((sqrt * sqrt) <= num) && (sqrt == 255 || ((sqrt+1'b1)*(sqrt+1'b1)) > num))) $fatal;
/* verilator lint_on WIDTHEXPAND */
		end
		$finish;
	end
endmodule
