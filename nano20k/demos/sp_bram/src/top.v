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
    reg [31:0] counter;

    localparam
        WAIT=0,
        INIT=1,
        STORE=2,
        STORE_MSG=3,
        LOAD=4,
        LOAD_MSG=5,
        START_SERIAL=6,
        WAIT_SERIAL=7,
        WAIT_DELAY=8,
        PAUSE=9,
        WAIT_SERIAL_2=10;

    always @(posedge clk) begin
        if (!rst_n) begin
            enable <= 0;
            wr_en <= 0;
            addr <= 0;
            be <= 0;
            hl_trigger <= 0;
            hl_val <= 0;
            data <= 3;
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
            INIT:                               // print a quick hello message
                begin
                    hl_val <= 32'h33112244;     // should output 0x33112244 to the serial port
                    hl_trigger <= 1;
                    state <= WAIT_SERIAL;
                    tag <= STORE;
                end
            STORE:
                begin
                    be <= 4'b1111;              // 32-bit
                    i_data[31:0] <= data;       // data
                    wr_en <= 1;                 // write
                    enable <= 1;                // enable bus
                    tag <= STORE_MSG;           // next is output a token to say we got through the write cycle
                    state <= WAIT;
                end
           STORE_MSG:
                begin
                    hl_val <= 32'h000000AA;     // write out 000000AA
                    hl_trigger <= 1;
                    state <= WAIT_SERIAL;
                    tag <= LOAD;
                end
           LOAD:
                begin
                    be <= 4'b1111;              // 32-bit
                    wr_en <= 0;                 // read
                    enable <= 1;                // enable bus
                    state <= WAIT;
                    tag <= LOAD_MSG;
                end
           LOAD_MSG:
                begin
                    hl_val <= 32'h000000BB;     // output 000000BB to say we got through the read cycle
                    hl_trigger <= 1;
                    state <= WAIT_SERIAL;
                    tag <= START_SERIAL;
                    addr[12:0] <= addr[12:0] + 13'd4;   // advance the address by 4 mod 8192
                    data <= data + 32'b1;
                end
           START_SERIAL:
                begin
                    hl_val <= o_data;           // write back what we read
                    hl_trigger <= 1;
                    state <= WAIT_SERIAL;
                    tag <= PAUSE;
                end
           PAUSE:
                begin
                    counter <= 27_000_000 / 2;  // pause half a second
                    tag <= STORE;
                    state <= WAIT_DELAY;
                end
           WAIT_SERIAL:
                begin
                    state <= WAIT_SERIAL_2;     // takes 1 cycle for hl_busy to be asserted...
                end
           WAIT_SERIAL_2:
                begin
                    hl_trigger <= 0;
                    if (!hl_busy) begin
                        state <= tag;
                    end
                end
            WAIT_DELAY:
                begin
                    if (!counter) begin
                        state <= tag;
                    end else begin
                        counter <= counter - 1'b1;
                    end
                end
            endcase
        end
    end
endmodule