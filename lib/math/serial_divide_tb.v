`timescale 1ns/1ps

module serial_divide_tb();
	reg clk;
	reg rst_n;

	localparam
		BIT_WIDTH=16;
		
	reg [BIT_WIDTH-1:0] num;
	reg [BIT_WIDTH-1:0] denom;
	reg valid;
	
	wire [BIT_WIDTH-1:0] quotient;
	wire [BIT_WIDTH-1:0] remainder;
	wire ready;
	
	serial_divide #(.BIT_WIDTH(BIT_WIDTH)) serial_divider (
		.clk(clk),
		.rst_n(rst_n),
		.num(num), .denom(denom), .valid(valid),
		.ready(ready), .quotient(quotient), .remainder(remainder));

    // Parameters for the simulation
    localparam CLK_PERIOD = 20; // 50MHz Clock
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;
    
    integer i;
	
	initial begin
        // Waveform setup
        $dumpfile("serial_divide.vcd");
        $dumpvars(0, serial_divide_tb);
		clk = 0;
		valid = 0;
		num = 0;
		denom = 0;

        // Reset system
        repeat(3) @(posedge clk);
        rst_n = 1;
		@(posedge clk); #1;
		
		// divide 27 by 4
		num = 27;
		denom = 4;
		valid = 1;
		wait(ready == 1); #1;
		valid = 0;
		@(posedge clk); #1;
		if (quotient != 6) begin
			$display("Quotient not 6 ... %d (dude I'm not mad I'm disappointed.)", quotient);
			$fatal;
		end
		if (remainder != 3) begin
			$display("Dude, like not cool.  The remainder ain't supposed to be no %d", remainder);
			$fatal;
		end
		
		// normally at this point testing would be considered complete.  But for the sake of being a "perfectionist"
		// I guess we could try some random numbers
		for (i = 0; i < 500000; i = i + 1) begin
/* verilator lint_off WIDTHTRUNC */
			num = $urandom_range(0, ((1<<BIT_WIDTH)-1));
			if (i < 100000)
				denom = $urandom_range(0, (1 << (BIT_WIDTH)) - 1);
			else
				denom = $urandom_range(0, (1 << (BIT_WIDTH-8)) - 1);
/* verilator lint_on WIDTHTRUNC */
			valid = 1;
			wait(ready == 1); #1;
			valid = 0;
			@(posedge clk); #1;
			$display("n=%x d=%x, q=%x, r=%x", num, denom, quotient, remainder);
			if (denom == 0) begin
				if (quotient != 0 || remainder != 0) $fatal;
			end else begin
				if (quotient * denom + remainder != num) $fatal;
			end
		end
		$finish;
	end
endmodule
