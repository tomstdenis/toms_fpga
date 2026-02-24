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

    spi_sram 
    #(
            .CLK_FREQ_MHZ(169), .FIFO_DEPTH(32), .SRAM_ADDR_WIDTH(16),
            .DUMMY_BYTES(1), .CMD_READ(8'h03), .CMD_WRITE(8'h02), .CMD_EQIO(8'h38),
            .MIN_CPH_NS(5), .SPI_TIMER_BITS(8), .QPI_TIMER_BITS(8)                     // divide by 128 to get ~1MHz breadboard clock
    ) test_sram(
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
        .sio_pin(sio), .cs_pin(cs), .sck_pin(sck));

    reg [2:0] state;
    reg [2:0] tag;

    localparam
        STATE_STUFF_FIFO = 0,
        STATE_ISSUE_WRITE = 1,
        STATE_ISSUE_READ = 2,
        STATE_COMPARE_READ = 3,
        STATE_SUCCESS = 4,
        STATE_FAILURE = 5,
        STATE_WAIT_DONE = 6;

    assign led = ~state;

    always @(posedge pll_clk) begin
        if (!rst_n) begin
            // these must be initialized in reset
            sram_data_in_valid <= 0;
            sram_data_out_read <= 0;
            sram_write_cmd <= 0;
            sram_read_cmd <= 0;
            sram_data_in <= 0;
            sram_read_cmd_size <= 0;
            sram_address <= 0;
            state <= STATE_WAIT_DONE;
            tag <= STATE_STUFF_FIFO;
        end else begin
            case(state)
                STATE_WAIT_DONE:
                    begin
                        sram_data_in_valid <= 0;
                        sram_data_out_read <= 0;
                        if (sram_done) begin
                            state <= tag;
                        end
                    end
                STATE_STUFF_FIFO:
                    begin
                        sram_data_in <= 8'hAA;
                        sram_data_in_valid <= 1;
                        state <= STATE_WAIT_DONE;
                        tag <= STATE_ISSUE_WRITE;
                    end
                STATE_ISSUE_WRITE:
                    begin
                        sram_write_cmd <= 1;
                        sram_address <= 24'h001122;
                        tag <= STATE_ISSUE_READ;
                        state <= STATE_WAIT_DONE;
                    end
                STATE_ISSUE_READ:
                    begin
                        sram_read_cmd <= 1;
                        sram_read_cmd_size <= 1;
                        sram_address <= 24'h001122;
                        tag <= STATE_COMPARE_READ;
                        state <= STATE_WAIT_DONE;
                    end
                STATE_COMPARE_READ:
                    begin
                        if (sram_data_out == 8'hAA) begin
                            state <= STATE_SUCCESS;
                        end else begin
                            state <= STATE_FAILURE;
                        end
                    end
                default: begin end
            endcase
        end         
    end
endmodule