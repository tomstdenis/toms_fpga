`define USE_MEM

module top(
    input clk,
    output pwm,     // output pwm signal here (which is mapped to the LED on the tang nano 20k)
    output timer    // 50% wave at the timer frequency
);
`ifdef USE_MEM
`include "src/timer/timer_mem.vh"

    reg [3:0] rstcnt = 4'b0;
    wire rst_n;
    assign rst_n = rstcnt[3];
    always @(posedge clk) begin
        rstcnt <= {rstcnt[2:0], 1'b1};
    end

    reg enable;
    reg wr_en;
    reg [31:0] addr;
    reg [31:0] i_data;
    reg [3:0] be;
    wire ready;
    wire [31:0] o_data;
    wire irq;
    wire bus_err;

    timer_mem tim(
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .wr_en(wr_en),
        .addr(addr),
        .i_data(i_data),
        .be(be),
        .ready(ready),
        .o_data(o_data),
        .irq(irq),
        .bus_err(bus_err),
        .pwm(pwm));
        
    localparam
        WAIT_FOR_READY=0,
        LOAD_TOP=2,
        LOAD_CMP=3,
        LOAD_PRESCALER=4,
        LOAD_ENABLE=5,
        READ_COUNTER=6,
        LATCH_COUNTER=7;

    reg [15:0] counter;
    reg [3:0] tag;
    reg [3:0] state = LOAD_TOP;
    reg [31:0] o_data_latch;

    assign timer = counter[7];

    always @(posedge clk) begin
        case(state)
            WAIT_FOR_READY:
                begin
                    if (!enable) begin
                        enable <= 1;
                    end else if (ready) begin
                        o_data_latch <= o_data[31:0];
                        enable <= 0;        // disable core
                        wr_en <= 0;         // deassert write
                        state <= tag;       // jump to tag state
                    end
                end
            LOAD_TOP:
                begin
                    wr_en = 1;              // WRITE
                    be <= 4'b1111;          // 32-bit
                    addr <= `TIMER_TOP_L_ADDR;
                    i_data <= 32'd255;      // TOP=255
                    tag <= LOAD_CMP;        // Next state is load CMP
                    state <= WAIT_FOR_READY;// Wait for bus transaction
                end
            LOAD_CMP:
                begin
                    wr_en = 1;               // WRITE
                    be <= 4'b1111;           // 32-bit
                    addr <= `TIMER_CMP_L_ADDR;
                    i_data <= 32'd64;        // CMP=64 (25% duty cycle)
                    tag <= LOAD_PRESCALER;   // Next state is load prescaler
                    state <= WAIT_FOR_READY; // Wait for bus transaction
                end
            LOAD_PRESCALER:
                begin
                    wr_en = 1;                 // WRITE
                    be <= 4'b0001;             // 8-bit
                    addr <= `TIMER_PRESCALE_ADDR;
                    i_data <= 32'd3;           // Prescaler == 3
                    tag <= LOAD_ENABLE;        // Next state is load enable
                    state <= WAIT_FOR_READY;   // Wait for bus transaction
                end
            LOAD_ENABLE:
                begin
                    wr_en = 1;              // WRITE
                    be <= 4'b0001;          // 8-bit
                    addr <= `TIMER_ENABLE_ADDR;
                    i_data <= 32'd1;        // Enable == 1
                    tag <= READ_COUNTER;        // Next state is read counter
                    state <= WAIT_FOR_READY;   // Wait for bus transaction
                end
            READ_COUNTER:
                begin
                    wr_en = 0;              // READ
                    be <= 4'b0011;          // 16-bit
                    addr <= `TIMER_COUNTER_L_ADDR;
                    tag <= LATCH_COUNTER;        // Next state is latch counter
                    state <= WAIT_FOR_READY;   // Wait for bus transaction
                end
            LATCH_COUNTER:
                begin
                    counter <= o_data_latch[15:0];
                    state <= READ_COUNTER;
                end
        endcase
    end
`else
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
`endif
endmodule