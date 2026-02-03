module top(
    input clk,
    output tx_pin
);

    wire rst_n;
    reg [3:0] rstcnt = 4'b0;
    assign rst_n = rstcnt[3];

    always @(posedge clk) begin
        rstcnt <= {rstcnt[2:0], 1'b1};
    end
    
    reg enable;
    reg wr_en;
    reg [31:0] addr;
    reg [31:0] i_data;
    reg [3:0] be;
    wire [31:0] o_data;
    wire ready;
    wire irq;
    wire bus_err;

    sp_bram mem(.clk(clk), .rst_n(rst_n), .enable(enable), .wr_en(wr_en), .addr(addr), .i_data(i_data), .be(be), .ready(ready), .o_data(o_data), .irq(irq), .bus_err(bus_err));
    
    reg hl_trigger;
    reg [31:0] hl_val;
    wire hl_busy;

    uart_hex_logger hl(.clk(clk), .rst_n(rst_n), .baud_div(16'd234), .trigger(hl_trigger), .hex_val(hl_val), .tx_pin(tx_pin), .busy(hl_busy));

    reg [3:0] state;
    reg [3:0] tag;
    reg [31:0] data;

    localparam
        WAIT=0,
        INIT=1,
        STORE=2,
        STORE_MSG=3,
        LOAD=4,
        LOAD_MSG=5,
        START_SERIAL=6,
        WAIT_SERIAL=7;

    always @(posedge clk) begin
        if (!rst_n) begin
            enable <= 0;
            wr_en <= 0;
            addr <= 0;
            be <= 0;
            hl_trigger <= 0;
            hl_val <= 0;
            data <= 0;
            state <= INIT;
        end else begin
            case(state)
            WAIT:
                begin
                    if (ready) begin
                        enable <= 0;
                        state <= tag;
                    end
                end
            INIT:
                begin
                    hl_val <= 32'h33112244;
                    hl_trigger <= 1;
                    state <= WAIT_SERIAL;
                    tag <= STORE;
                end
            STORE:
                begin
                    addr <= 0;
                    be <= 4'b1111;
                    i_data[31:0] <= data;
                    data <= data + 32'b1;
                    wr_en <= 1;
                    enable <= 1;
                    tag <= STORE_MSG;
                    state <= WAIT;
                end
           STORE_MSG:
                begin
                    hl_val <= 32'h000000AA;
                    hl_trigger <= 1;
                    state <= WAIT_SERIAL;
                    tag <= LOAD;
                end
           LOAD:
                begin
                    addr <= 0;
                    be <= 4'b1111;
                    wr_en <= 0;
                    enable <= 1;
                    tag <= LOAD_MSG;
                    state <= WAIT;
                end
           LOAD_MSG:
                begin
                    hl_val <= 32'h000000BB;
                    hl_trigger <= 1;
                    state <= WAIT_SERIAL;
                    tag <= START_SERIAL;
           end
           START_SERIAL:
                begin
                    hl_val <= o_data;
                    hl_trigger <= 1;
                    state <= WAIT_SERIAL;
                    tag <= STORE;
                end
           WAIT_SERIAL:
                begin
                    hl_trigger <= 0;
                    if (!hl_busy) begin
                        state <= tag;
                    end
                end
            endcase        
        end
    end
endmodule