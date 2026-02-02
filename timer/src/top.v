module top(
    input clk,
    output pwm,     // output pwm signal here (which is mapped to the LED on the tang nano 20k)
    output timer    // 50% wave at the timer frequency
);
    wire [7:0] prescaler = 8'd3;
    wire [15:0] top = 16'd255;
    reg [15:0] cmp = 16'd128;
    wire go = 1'b1;
    wire [15:0] counter;
    wire pwm_sig;
    reg [24:0] demo_clock;
    reg relatch = 0;

    assign pwm = ~pwm_sig;
    assign timer = counter[7]; // because top is 8 bits we check the msb of top not counter..

    reg [3:0] rstcnt = 4'b0;
    assign rst_n = rstcnt[3];

    // 27MHz / (prescaler + 1) / (top + 1) => output frequency (in this case with p=3,t=255 => 26367Hz)
    timer tim (.clk(clk), 
        .rst_n(rst_n), 
        .prescaler_cnt(prescaler), 
        .top_cnt(top), 
        .cmp_cnt(cmp), 
        .go(go), .relatch(relatch),
        .cmp_match(), .top_match(), .pwm(pwm_sig), .counter(counter));

    always @(posedge clk) begin
        rstcnt <= {rstcnt[2:0], 1'b1};
        demo_clock <= demo_clock + 1'b1;
        if (demo_clock[20]) begin                   // every 2**20 cycles let's update the PWM duty cycle
            case(demo_clock[0])
                1'b0:                               // on cycle 0 we say to relatch the new parameters
                    begin
                        relatch <= 1;
                        cmp <= (cmp + 1) & 8'hff;
                    end
                1'b1:
                    begin
                        demo_clock <= 0;            // reset demo clock
                        relatch <= 0;               // tell the timer to not latch anymore
                    end
            endcase
        end
    end

endmodule