/* verilator lint_off MULTIDRIVEN */
`timescale 1ns/1ps
`default_nettype none
module blinky_tb();
    // Signals for clock and reset
    logic clk;
    logic rst_n;

    // Parameters for the simulation
    localparam CLK_PERIOD = 20;             // 50MHz Clock

    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // instantiate our blinky module
    parameter TIMER_BITS = 10;              // let's use a 10-bit timer instead
    logic [TIMER_BITS-1:0] target;          // the target to count to
    logic valid;                            // our valid signal to say when a new value should be latched
    logic match;                            // our view of the match signal 

    // instantiate blinky as blinky_dut
    blinky #(                               // parameters if any start with #(
        .TIMER_WIDTH(TIMER_BITS)            // .INNER(OUTER), INNER is the modules parameter, OUTER is anything else (notice how I renamed it BITS)
    ) blinky_dut (                          // module instance is called blinky dut
        .clk(clk),                          // our clock signal
        .rst_n(rst_n),                      // active low reset
        .compare(target),                   // compare target, note the scope of the names
        .valid(valid),                      // compare target is valid
        .match(match)                       // there is a match
    );

    // --- Verification Logic ---
	integer i;
    initial begin
        // create a waveform file blinky.vcd
        $dumpfile("blinky.vcd");
        // dump this modules signals to it
        $dumpvars(0, blinky_tb);

        // Initialize signals so we start in reset
        clk   = 0;
        rst_n = 0;

        // wait till the logic below increment sthe target to 32
        wait(target == 32);

        // tell the simulator we're done
        $finish;
    end

    always_ff @(posedge clk) begin
        // default to clearing the valid signal
        valid <= 1'b0;

        // the blinky told us the timer matched 
        if (match) begin
            valid  <= 1'b1;                 // raise valid
            target <= target + 1'b1;        // increment target
        end

        // our reset condition
        if (~rst_n) begin
            valid  <= 1'b1;                 // come out of reset with a valid compare target
            target <= 1;                    // reset to a count of 2 (recall the real count is +1)
            rst_n  <= 1'b1;                 // bring ourself out of reset for this test bench
        end
    end
endmodule
