/* Simple compare/top counter

 Provides a PWM signal based on the compare value programmed.  Counts up to prescaler_cnt and then increments counter.
 
 The cmp_match is set when counter <= cmp_cmp.  The top_match is set when counter == top_cnt.  Note that
top_match will be set for the last prescaler_cnt cycle before rolling counter over to zero.

*/

`timescale 1ns/1ps

module timer#(parameter PRESCALER_BITS=8, TIMER_BITS=16)
(
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
);

    reg [PRESCALER_BITS-1:0] prescaler;
    reg [PRESCALER_BITS-1:0] prescaler_n;
    reg [TIMER_BITS-1:0] top;
    reg [TIMER_BITS-1:0] compare;
    reg [TIMER_BITS-1:0] count;
    reg go_l;

    // output 1 if we hit the compare value
    assign cmp_match = (rst_n & go_l & (compare == count));
    // output 1 if we hit the top value
    assign top_match = (rst_n & go_l & (top == (count + 1'b1)) & (prescaler_n == (prescaler_cnt - 1)));
    // output 1 during the on phase of the PWM 
    assign pwm = (rst_n & go_l & (count <= compare));
    // provide a copy of the counter externally
    assign counter = count;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            prescaler <= 0;
            prescaler_n <= 0;
            top <= 0;
            compare <= 0;
            count <= 0;
            go_l <= 0;
        end else begin
            if (!go_l && go) begin
                // go was off now it's on so load up the latched values
                prescaler <= prescaler_cnt;
                top <= top_cnt;
                compare <= cmp_cnt;
                count <= 0;
                prescaler_n <= 0;
                go_l <= go;
            end else if (go_l) begin
                // did it get turned off?
                if (!go) begin
                    go_l <= go;
                end else begin
                    if (relatch) begin
                        // the user wants to store new timer parameters on the fly
                        compare <= cmp_cnt;
                        top <= top_cnt;
                        prescaler <= prescaler_cnt;
                    end else begin
                        // no updates or stops so advance the prescaler_n
                        if ((prescaler_n + 1'b1) == prescaler) begin
                            // we hit the prescaler so increment the counter
                            prescaler_n <= 0;
                            if ((count + 1'b1) == top) begin
                                // we hit the top so reset it
                                count <= 0;
                            end else begin
                                count <= count + 1'b1;
                            end
                        end else begin
                            prescaler_n <= prescaler_n + 1'b1;
                        end
                    end
                end
            end
        end
    end
endmodule
