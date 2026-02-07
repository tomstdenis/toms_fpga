`timescale 1ns/1ps

module timer_tb();
	reg clk;
	reg rst_n;
	reg [3:0] prescaler_cnt;
	reg [15:0] top_cnt;
	reg [15:0] cmp_cnt;
	reg go;
	reg relatch;
	
	wire cmp_match;
	wire top_match;
	wire pwm;
	wire [15:0] counter;
	
	reg [7:0] phase;
	
	timer #(.PRESCALER_BITS(4), .TIMER_BITS(16)) t1 (
		.clk(clk), .rst_n(rst_n),
		.prescaler_cnt(prescaler_cnt), .top_cnt(top_cnt), .cmp_cnt(cmp_cnt),
		.go(go), .relatch(relatch),
		
		.cmp_match(cmp_match), .top_match(top_match), .pwm(pwm), .counter(counter));
/*
    input clk,
    input rst_n,
    input [PRESCALER_BITS-1:0] prescaler_cnt,   // what to divide clock by (prescaler_cnt + 1)
    input [TIMER_BITS-1:0] top_cnt,             // top count before resetting counter (divides clk further by top_cnt + 1)
    input [TIMER_BITS-1:0] cmp_cnt,             // compare count for PWM
    input go,                                   // run the timer (needs to be asserted to get timer outputs)
    input relatch,                              // relatch new parameters, deassert the next cycle

    output cmp_match,                           // (out) 1 if counter == cmp_cnt
    output top_match,                           // (out) 1 if counter == top_cnt
    output pwm,                                 // (out) 1 if counter <= cmp_cnt
    output [TIMER_BITS-1:0] counter             // (out) the raw counter value
*/

    // Parameters for the simulation
    localparam CLK_PERIOD = 20; // 50MHz Clock
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Verification Logic ---
    
	integer i;
	integer j;
    initial begin
        // Setup for OSS CAD (GTKWave)
        $dumpfile("timer.vcd");
        $dumpvars(0, timer_tb);

        // Initialize signals
        clk = 0;
        rst_n = 0;
        prescaler_cnt = 0;
        top_cnt = 0;
        cmp_cnt = 0;
        phase = 0;
        go = 0;
        relatch = 0;

        // Reset
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // set prescaler to 4, and top to 16, so top should toggle every 64 cycles
        prescaler_cnt = 4;
        top_cnt = 16;
        cmp_cnt = 7;
        go = 1;
        @(posedge clk); // latch values
        if (cmp_match !== 0 || top_match !== 0) begin
			$display("Match should be zero %h %h", cmp_match, top_match);
			$fatal;
		end
		// clock it
		for (i = 0; i < 512; i++) begin
			@(posedge clk);
			// top match will be high for prescale_cnt # of clock cycles 
			if (top_match !== 0 && i > 0 && ((i % 64) < 60)) begin
				$display("Top match is wrong at step %h", i);
				repeat(16) @(posedge clk);
				$fatal;
			end
			if (cmp_match == 1 && counter != 7) begin
				$display("Compare match is wrong at step %d", i);
				repeat(16) @(posedge clk);
				$fatal;
			end
			if (pwm == 0 && counter <= cmp_cnt) begin
				$display("Invalid PWM signal at step %d", i);
				repeat(16) @(posedge clk);
				$fatal;
			end				
		end
        $finish;
	end
endmodule
