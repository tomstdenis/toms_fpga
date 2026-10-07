// this tells the tool that any net without a type should throw an error
`default_nettype none
`timescale 1ns/1ps

// this is a module, modules are basic blocks that
// provide a means to modular design
module blinky
// parameters (if any) start with a #() block
// parameters are constants that can change the design of the logic
// they can also be passed higher up in the instantiating layer
#(
    parameter TIMER_WIDTH = 16  // 16 bit counter
)
(
    input logic                   clk,      // clock signal
    input logic                   rst_n,    // active low reset

    input logic [TIMER_WIDTH-1:0] compare,  // the value to compare to
    input logic                   valid,    // compare value is latched when this is high

    output logic                  match     // goes high when the timer matches the compare
);

    logic [TIMER_WIDTH-1:0] counter;        // declares a logic net TIMER_WIDTH bits in size named "counter"
    logic [TIMER_WIDTH-1:0] target;
    logic counter_matches;                  // this is a single bit logic net
    
    // always_comb blocks are where combinatorial logic happens.  These
    // expressions are constantly evalutated
    always_comb begin
        match = counter_matches;            // assign match signal
    end

    // always_ff blocks are evaluated (latched) on a condition,
    // in this case the positive edge of the clk signal.
    always_ff @(posedge clk) begin
        // default is increment the counter and not a match
        counter         <= counter + 1'b1;
        counter_matches <= 1'b0;

        // if the counter matches, now recall we're comparing counter to what it was
        // at the start of the cycle so the above + 1'b1 will not be reflected here
        // which means a target of 1 means it matches every 2 cycles (counter == 0, counter == 1)
        if (counter == target) begin
            counter_matches <= 1'b1;        // this takes precedence over the default
            counter         <= 0;           // similarly now counter will latch to 0 unless something else changes it
        end 

        // handle a new compare value to use
        if (valid) begin
            target          <= compare;     // latch a new timer target
            counter         <= 0;           // reset counter to 0
            counter_matches <= 1'b0;        // reset match to 0
        end

        // handle reset last so it has highest precedence
        // basically put nets into their default state here
        if (~rst_n) begin
            counter         <= 1;               // decimal 1, set the counter to 1 meaning every 2 cycles
            counter_matches <= 1'b0;            // 1-bit '0', default to not matched
        end
    end
endmodule