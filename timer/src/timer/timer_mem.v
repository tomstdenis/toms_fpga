`include "timer_mem.vh"

module timer_mem
#(
    parameter ADDR_WIDTH=32,
    parameter DATA_WIDTH=32
)(
    // common bus in
    input clk,
    input rst_n,            // active low reset
    input enable,           // active high overall enable (must go low between commands)
    input wr_en,            // active high write enable (0==read, 1==write)
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] i_data,
    input [DATA_WIDTH/8-1:0] be,       // lane 0 must be asserted, other lanes can be asserted but they're ignored.

    // common bus out
    output reg ready,       // active high signal when o_data is ready (or write is done)
    output reg [DATA_WIDTH-1:0] o_data,
    output wire irq,        // active high IRQ pin
    output wire bus_err,    // active high error signal

    // peripheral specific
    output pwm
);
    reg [15:0] l_top;
    reg [15:0] l_cmp;
    reg [7:0]  l_prescaler;
    reg l_relatch;
    reg l_go;
    reg [1:0] int_enables;  // count==top, count==compare
    reg [1:0] int_pending;
    reg error;
    wire cur_cmp_match;
    wire cur_top_match;
    reg prev_cmp_match;
    reg prev_top_match;
    wire [15:0] cur_counter;
    reg [15:0] l_counter;
    reg state;
    reg [7:0] i_data_latch;

    localparam
        ISSUE=0,
        RETIRE=1;

    // IRQ output if either interrupt is enabled and pending
    assign irq = (int_enables[0] & int_pending[0]) | (int_enables[1] & int_pending[1]);

    // error output is only valid out of reset
    assign bus_err = error & rst_n;

    timer tim(
        .clk(clk), .rst_n(rst_n),
        .prescaler_cnt(l_prescaler),
        .top_cnt(l_top),
        .cmp_cnt(l_cmp),
        .go(l_go),
        .relatch(l_relatch),
        .cmp_match(cur_cmp_match),
        .top_match(cur_top_match),
        .pwm(pwm),
        .counter(cur_counter));

    always @(posedge clk) begin
        if (!rst_n) begin
            l_top <= 16'b0;
            l_cmp <= 16'b0;
            l_prescaler <= 8'b0;
            l_relatch <= 0;
            l_go <= 0;
            int_enables <= 2'b0;
            int_pending <= 2'b0;
            error <= 0;
            prev_cmp_match <= 0;
            prev_top_match <= 0;
            l_counter <= 16'b0;
            i_data_latch <= 8'b0;
            state <= ISSUE;
        end else begin
            // latch matches to set pending int flags
            if (cur_top_match && !prev_top_match) begin
                int_pending[`TIMER_INT_TOP_MATCH] <= 1'b1;
            end
            if (cur_cmp_match && !prev_cmp_match) begin
                int_pending[`TIMER_INT_CMP_MATCH] <= 1'b1;
            end
            prev_top_match <= cur_top_match;
            prev_cmp_match <= cur_cmp_match;

            // must write to first lane
            if (~be[0]) begin           // ensure that the first lane is active
                ready <= 1;
                error <= 1;
            end else begin
                if (!error & enable & !ready) begin     // only process the command if we're not in an error state and not waiting for the master to acknowledge the previous command
                    case(state)
                        ISSUE:
                            begin
                                if (wr_en) begin
                                    case(addr)
                                        `TIMER_TOP_H_ADDR:
                                            begin
                                                l_top[15:8] <= i_data[7:0];
                                                l_relatch <= 1;
                                            end
                                        `TIMER_TOP_L_ADDR:
                                            begin
                                                l_top[7:0] <= i_data[7:0];
                                                l_relatch <= 1;
                                            end
                                        `TIMER_CMP_H_ADDR:
                                            begin
                                                l_cmp[15:8] <= i_data[7:0];
                                                l_relatch <= 1;
                                            end
                                        `TIMER_CMP_L_ADDR:
                                            begin
                                                l_cmp[7:0] <= i_data[7:0];
                                                l_relatch <= 1;
                                            end
                                        `TIMER_PRESCALE_ADDR:
                                            begin
                                                l_prescaler[7:0] <= i_data[7:0];
                                                l_relatch <= 1;
                                            end
                                        `TIMER_INT_ENABLE_ADDR:
                                            begin
                                                int_enables[1:0] <= i_data[1:0];
                                            end
                                        `TIMER_INT_PENDING_ADDR:
                                            begin
                                            end
                                        `TIMER_ENABLE_ADDR:
                                            begin
                                                l_go <= i_data[0];
                                            end
                                        `TIMER_COUNTER_H_ADDR:
                                            begin
                                            end
                                        `TIMER_COUNTER_L_ADDR:
                                            begin
                                            end
                                        default:
                                            begin
                                                error <= 1; // invalid address
                                            end
                                    endcase
                                end else begin // reads
                                    case(addr)
                                        `TIMER_TOP_H_ADDR:
                                            begin
                                                o_data <= {24'b0, l_top[15:8]};
                                            end
                                        `TIMER_TOP_L_ADDR:
                                            begin
                                                o_data <= {24'b0, l_top[7:0]};
                                            end
                                        `TIMER_CMP_H_ADDR:
                                            begin
                                                o_data <= {24'b0, l_cmp[15:8]};
                                            end
                                        `TIMER_CMP_L_ADDR:
                                            begin
                                                o_data <= {24'b0, l_cmp[7:0]};
                                            end
                                        `TIMER_PRESCALE_ADDR:
                                            begin
                                                o_data <= {24'b0, l_prescaler[7:0]};
                                            end
                                        `TIMER_INT_ENABLE_ADDR:
                                            begin
                                                o_data <= {30'b0, int_enables[1:0]};
                                            end
                                        `TIMER_INT_PENDING_ADDR:
                                            begin
                                                o_data <= {30'b0, int_pending[1:0]};
                                            end
                                        `TIMER_ENABLE_ADDR:
                                            begin
                                                o_data <= {31'b0, l_go};
                                            end
                                        `TIMER_COUNTER_L_ADDR:
                                            begin
                                                l_counter <= cur_counter;
                                                o_data <= {24'b0, cur_counter[7:0]};
                                            end
                                        `TIMER_COUNTER_H_ADDR:
                                            begin
                                                o_data <= {24'b0, l_counter[15:8]};
                                            end
                                        default:
                                            begin
                                                error <= 1; // invalid address
                                            end
                                    endcase
                                end
                                state <= RETIRE;
                            end
                        RETIRE:
                            begin
                                l_relatch <= 0; // disable relatching after issuing new parameters
                                ready <= 1;
                            end
                    endcase
                end else if (!enable) begin
                    error <= 0;
                    ready <= 0;
                    state <= ISSUE;
                end
            end
        end
    end
endmodule    