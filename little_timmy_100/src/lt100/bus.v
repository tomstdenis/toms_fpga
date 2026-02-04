module lt100_bus
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
    input rx_pin,
    output tx_pin,
    output pwm
);
    localparam
        P_BSRAM = 4'd0,
        P_TIMER = 4'd1,
        P_UART  = 4'd2;

    reg op_enable;              // this is our enable signal out to the peripherals
    reg [DATA_WIDTH-1:0] op_i_data;
    reg [ADDR_WIDTH-1:0] op_addr;
    reg op_wr_en;
    reg [DATA_WIDTH/8-1:0] op_be;
    
    wire [2:0] p_enable;
    wire [2:0] p_ready;
    wire [2:0] p_bus_err;
    wire [2:0] p_irq;
    wire [DATA_WIDTH-1:0] p_out[2:0];

    assign p_enable[P_BSRAM] = op_enable & ((addr[31:28]) == P_BSRAM); // bsram
    assign p_enable[P_TIMER] = op_enable & ((addr[31:28]) == P_TIMER); // timer
    assign p_enable[P_UART]  = op_enable & ((addr[31:28]) == P_UART); // uart
    assign irq = |p_irq;
    assign bus_err = |p_bus_err;

    sp_bram p_bram(
        .clk(clk), .rst_n(rst_n), .enable(p_enable[P_BSRAM]), .wr_en(op_wr_en), .addr({4'b0, op_addr[27:0]}), .i_data(op_i_data), .be(op_be),
        .ready(p_ready[P_BSRAM]), .o_data(p_out[P_BSRAM]), .irq(p_irq[P_BSRAM]), .bus_err(p_bus_err[P_BSRAM]), .pwm(pwm));

    timer_mem p_timer(
        .clk(clk), .rst_n(rst_n), .enable(p_enable[P_TIMER]), .wr_en(op_wr_en), .addr({4'b0, op_addr[27:0]}), .i_data(op_i_data), .be(op_be),
        .ready(p_ready[P_TIMER]), .o_data(p_out[P_TIMER]), .irq(p_irq[P_TIMER]), .bus_err(p_bus_err[P_TIMER]), .pwm(pwm));

    uart_mem p_uart(
        .clk(clk), .rst_n(rst_n), .enable(p_enable[P_UART]), .wr_en(op_wr_en), .addr({4'b0, op_addr[27:0]}), .i_data(op_i_data), .be(op_be),
        .ready(p_ready[P_UART]), .o_data(p_out[P_UART]), .irq(p_irq[P_UART]), .bus_err(p_bus_err[P_UART]), .tx_pin(tx_pin), .rx_pin(rx_pin));

    localparam
        ISSUE=0,
        RETIRE=1;

    reg state;

    always @(posedge clk) begin
        if (!rst_n) begin
            op_enable <= 0;
            op_i_data <= 0;
        end else begin
            if (!bus_err & enable & !ready) begin
                case(state)
                    ISSUE:
                        begin
                            op_i_data <= i_data;
                            op_addr <= addr;
                            op_be <= be;
                            op_wr_en <= wr_en;
                            op_enable <= 1;
                            state <= RETIRE;
                        end
                    RETIRE:
                        begin
                            if (|p_ready) begin
                                ready <= 1;
                                op_enable <= 0;
                                o_data <= p_out[op_addr[31:28]];
                                state <= ISSUE;
                            end
                        end
                endcase
            end else if (!enable) begin
                ready <= 0;
                op_enable <= 0;
                state <= ISSUE;
            end
        end
    end
endmodule
