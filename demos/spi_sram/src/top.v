module top(input clk, inout [3:0] sio, output cs, output sck, output [3:0] led);

    wire sram_done;
    reg [7:0] sram_data_in;
    reg sram_data_in_valid;
    wire [7:0] sram_data_out;
    reg sram_data_out_read;
    wire sram_data_out_empty;

    reg sram_write_cmd;
    reg sram_read_cmd;
    reg [5:0] sram_read_cmd_size;
    reg [23:0] sram_address;
    wire [15:0] sram_bauddiv = 108_000_000 / 100_000;             // sitting in a bread board let's clock this slowly...
    wire [15:0] sram_quaddiv = 108_000_000 / 100_000;
    reg [3:0] rstcnt = 4'b0;
    wire rst_n;
    assign rst_n = rstcnt[3];
    wire pll_clk;

    Gowin_rPLL mypll(
        .clkout(pll_clk), //output clkout
        .clkin(clk) //input clkin
    );

    always @(posedge pll_clk) begin
        rstcnt <= {rstcnt[2:0], 1'b1};
    end
    reg [3:0] leds;
    assign led = leds;

    spi_sram #(
            .CLK_FREQ_MHZ(108), .FIFO_DEPTH(32), .SRAM_ADDR_WIDTH(16),
            .DUMMY_BYTES(1), .CMD_READ(8'h03), .CMD_WRITE(8'h02),
            .CMD_EQIO(8'h38), .MIN_CPH_NS(50)) test_sram(
        .clk(pll_clk),
        .rst_n(rst_n),
        .done(sram_done),
        .data_in(sram_data_in),
        .data_in_valid(sram_data_in_valid),
        .data_out(sram_data_out),
        .data_out_read(sram_data_out_read),
        .data_out_empty(sram_data_out_empty),
        .write_cmd(sram_write_cmd),
        .read_cmd(sram_read_cmd),
        .read_cmd_size(sram_read_cmd_size),
        .address(sram_address),
        .sio_pin(sio), .cs_pin(cs), .sck_pin(sck), .spi_bauddiv(sram_bauddiv), .quad_bauddiv(sram_bauddiv));

    reg [3:0] state;
    reg [3:0] tag;

    localparam
        STATE_INIT = 0,
        STATE_STUFF_FIFO = 1,
        STATE_ISSUE_WRITE = 2,
        STATE_WAIT_WRITE = 3,
        STATE_ISSUE_READ = 4,
        STATE_WAIT_READ = 5,
        STATE_COMPARE_READ = 6;

    always @(posedge pll_clk) begin
        if (!rst_n) begin
            sram_data_in <= 0;
            sram_data_in_valid <= 0;
            sram_data_out_read <= 0;
            sram_write_cmd <= 0;
            sram_read_cmd <= 0;
            sram_read_cmd_size <= 0;
            sram_address <= 0;
            state <= STATE_INIT;
            leds <= 4'b1111;
        end else begin
            case(state)
                STATE_INIT:
                    begin
                        if (sram_done == 1) begin
                            state <= STATE_STUFF_FIFO;
                        end
                    end
                STATE_STUFF_FIFO:
                    begin
                        sram_data_in <= 8'hAA;
                        sram_data_in_valid <= 1;
                        state <= STATE_ISSUE_WRITE;
                    end
                STATE_ISSUE_WRITE:
                    begin
                        sram_data_in_valid <= 0;
                        sram_write_cmd <= 1;
                        sram_address <= 24'h001122;
                        state <= STATE_WAIT_WRITE;
                    end
                STATE_WAIT_WRITE:
                    begin
                        sram_write_cmd <= 0;
                        if (sram_done == 1) begin
                            state <= STATE_ISSUE_READ;
                        end
                    end
                STATE_ISSUE_READ:
                    begin
                        sram_read_cmd <= 1;
                        sram_read_cmd_size <= 1;
                        sram_address <= 24'h001122;
                        state <= STATE_WAIT_READ;
                    end
                STATE_WAIT_READ:
                    begin
                        sram_read_cmd <= 0;
                        if (sram_done == 1) begin
                            state <= STATE_COMPARE_READ;        // sram_data_out should be valid already since it's combinatorial...
                        end
                    end
                STATE_COMPARE_READ:
                    begin
                        if (sram_data_out == 8'hAA) begin
                            leds[0] <= 0;
                        end
                    end
            endcase
        end         
    end
endmodule