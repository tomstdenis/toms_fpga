module lt100_bus
#(
    parameter ADDR_WIDTH=32,
    parameter DATA_WIDTH=32
)(
    // common bus in
    input clk,
    input rst_n,            
    input enable,           
    input wr_en,            
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] i_data,
    input [DATA_WIDTH/8-1:0] be,       

    // common bus out
    output reg ready,       
    output reg [DATA_WIDTH-1:0] o_data,
    output wire irq,        
    output wire bus_err,    

    // peripheral specific
    input rx_pin,
    output tx_pin,
    output pwm
);
    // Peripheral Address Mapping
    localparam P_BSRAM = 4'd0;
    localparam P_TIMER = 4'd1;
    localparam P_UART  = 4'd2;

    // Internal registered bus signals
    reg [ADDR_WIDTH-1:0] op_addr;
    reg [DATA_WIDTH-1:0] op_i_data;
    reg [DATA_WIDTH/8-1:0] op_be;
    reg op_wr_en;
    reg op_active; // High when a transaction is currently being processed

    // Peripheral interconnect wires
    wire [2:0] p_enable;
    wire [2:0] p_ready;
    wire [2:0] p_bus_err;
    wire [2:0] p_irq;
    wire [DATA_WIDTH-1:0] p_out[2:0];

    // ---------------------------------------------------------
    // 1. IMPROVED DECODING LOGIC
    // ---------------------------------------------------------
    // We use the raw 'addr' for enable to kick off peripherals immediately.
    // We use 'op_addr' (registered) for the output mux to keep it stable.
    
    assign p_enable[P_BSRAM] = enable && (addr[31:28] == P_BSRAM) && !ready;
    assign p_enable[P_TIMER] = enable && (addr[31:28] == P_TIMER) && !ready;
    assign p_enable[P_UART]  = enable && (addr[31:28] == P_UART)  && !ready;

    wire op_bsram_sel = (op_addr[31:28] == P_BSRAM);
    wire op_timer_sel = (op_addr[31:28] == P_TIMER);
    wire op_uart_sel  = (op_addr[31:28] == P_UART);

    // High-speed AND-OR Mux
    wire [31:0] read_mux = ({32{op_bsram_sel}} & p_out[P_BSRAM]) | 
                           ({32{op_timer_sel}} & p_out[P_TIMER]) | 
                           ({32{op_uart_sel}}  & p_out[P_UART]);

    assign irq = |p_irq;
    assign bus_err = |p_bus_err;

    // ---------------------------------------------------------
    // 2. PERIPHERAL INSTANTIATION
    // ---------------------------------------------------------
    sp_bram p_bram(
        .clk(clk), .rst_n(rst_n), .enable(p_enable[P_BSRAM]), .wr_en(wr_en), 
        .addr({4'b0, addr[27:0]}), .i_data(i_data), .be(be),
        .ready(p_ready[P_BSRAM]), .o_data(p_out[P_BSRAM]), .irq(p_irq[P_BSRAM]), .bus_err(p_bus_err[P_BSRAM]));

    timer_mem p_timer(
        .clk(clk), .rst_n(rst_n), .enable(p_enable[P_TIMER]), .wr_en(wr_en), 
        .addr({4'b0, addr[27:0]}), .i_data(i_data), .be(be),
        .ready(p_ready[P_TIMER]), .o_data(p_out[P_TIMER]), .irq(p_irq[P_TIMER]), .bus_err(p_bus_err[P_TIMER]), .pwm(pwm));

    uart_mem p_uart(
        .clk(clk), .rst_n(rst_n), .enable(p_enable[P_UART]), .wr_en(wr_en), 
        .addr({4'b0, addr[27:0]}), .i_data(i_data), .be(be),
        .ready(p_ready[P_UART]), .o_data(p_out[P_UART]), .irq(p_irq[P_UART]), .bus_err(p_bus_err[P_UART]), .tx_pin(tx_pin), .rx_pin(rx_pin));

    // ---------------------------------------------------------
    // 3. BUS STATE MACHINE
    // ---------------------------------------------------------
    localparam STATE_IDLE = 1'b0;
    localparam STATE_WAIT = 1'b1;
    reg state;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            ready <= 0;
            o_data <= 0;
            op_addr <= 0;
        end else begin
            case(state)
                STATE_IDLE: begin
                    if (enable && !ready) begin
                        op_addr <= addr; // Capture address for the read mux
                        state <= STATE_WAIT;
                    end
                end

                STATE_WAIT: begin
                    if (|p_ready) begin
                        o_data <= read_mux;
                        ready <= 1;
                        state <= STATE_IDLE;
                    end
                end
            endcase

            // Synchronous Reset of the ready flag when CPU drops enable
            if (!enable) begin
                ready <= 0;
                state <= STATE_IDLE;
            end
        end
    end
endmodule