`include "spisddma.vh"
`define FREQ 48

module top(
    input wire clk,
    input wire rx_pin,
    output wire tx_pin,
    output wire [5:0] led,
    input wire miso_pin,
    output wire mosi_pin,
    output wire cs_pin,
    output wire sck_pin
);

    // our 48MHz clock
    wire pll_clk;

    spi_48mhz spi_clk(
        .clkout(pll_clk), //output clkout
        .clkin(clk)); //input clkin

    reg [3:0] rst = 0;
    wire rst_n = rst[3];

    always @(posedge pll_clk) begin
        rst <= { rst[2:0], 1'b1 };
    end

    // our uart
    wire [15:0] baud_div = (`FREQ * 1_000_000) / 500_000;
    reg uart_tx_start;
    reg [7:0] uart_tx_data_in;
    wire uart_tx_fifo_empty;
    wire uart_tx_fifo_full;
    reg uart_rx_read;
    wire uart_rx_ready;
    wire [7:0] uart_rx_byte;

    uart #(.FIFO_DEPTH(64), .RX_ENABLE(1), .TX_ENABLE(1)) spi_uart(
        .clk(pll_clk), .rst_n(rst_n),
        .baud_div(baud_div),
        .uart_tx_start(uart_tx_start), .uart_tx_data_in(uart_tx_data_in),
        .uart_tx_pin(tx_pin), .uart_tx_fifo_empty(uart_tx_fifo_empty),
        .uart_tx_fifo_full(uart_tx_fifo_full),
        .uart_rx_pin(rx_pin), .uart_rx_read(uart_rx_read),
        .uart_rx_ready(uart_rx_ready), .uart_rx_byte(uart_rx_byte));

    // the rom containing the sample data
    wire [7:0] test_rom_dout;
    reg [8:0] test_rom_addr;

    test_data spi_test_data(
        .dout(test_rom_dout), //output [7:0] dout
        .clk(pll_clk), //input clk
        .oce(1'b1), //input oce
        .ce(1'b1), //input ce
        .reset(~rst_n), //input reset
        .ad(test_rom_addr) //input [8:0] ad
    );

    // test memory
    reg host_mem_wr_en;
    wire [7:0] host_mem_data_out;
    reg [7:0] host_mem_data_in;
    reg [10:0] host_mem_addr;

    wire spi_mem_wr_en;
    wire [7:0] spi_mem_data_out;
    wire [7:0] spi_mem_data_in;
    wire [10:0] spi_mem_addr;

    test_mem spi_mem(
        .clka(pll_clk), //input clka
        .ocea(1'b1), //input ocea
        .cea(1'b1), //input cea
        .reseta(~rst_n), //input reseta
        .wrea(host_mem_wr_en), //input wrea
        .douta(host_mem_data_out), //output [7:0] douta
        .ada(host_mem_addr), //input [10:0] ada
        .dina(host_mem_data_in), //input [7:0] dina

        .doutb(spi_mem_data_out), //output [7:0] doutb
        .clkb(pll_clk), //input clkb
        .oceb(1'b1), //input oceb
        .ceb(1'b1), //input ceb
        .resetb(~rst_n), //input resetb
        .wreb(spi_mem_wr_en), //input wreb
        .adb(spi_mem_addr), //input [10:0] adb
        .dinb(spi_mem_data_in) //input [7:0] dinb
    );

    // our SPI SD controller
    wire spi_ready;
    wire [2:0] spi_error;
    wire spi_card_is_v1;
    wire spi_card_is_init;
    wire spi_card_is_sdhc;

    wire [4:0] spi_error_read;
    wire [7:0] spi_r2_status;

    reg  spi_cmd_wr_en;
    reg  spi_cmd_valid;
    reg [31:0] spi_cmd_sector;
    reg [10:0] spi_cmd_host_address;
    wire [63:0] spi_debug;

    spisddma #(.CLK_FREQ_MHZ(`FREQ), .READ_CRC_CHK(1), .FAST_CLK(24_000_000)) spi_sd (
        .clk(pll_clk), .rst_n(rst_n),
        .ready(spi_ready), .error(spi_error), .error_read(spi_error_read), .r2_status(spi_r2_status),
        .card_is_v1(spi_card_is_v1), .card_is_init(spi_card_is_init), .card_is_sdhc(spi_card_is_sdhc),
        .host_mem_addr(spi_mem_addr), .host_mem_wr_en(spi_mem_wr_en),
        .host_mem_data_in(spi_mem_data_in), .host_mem_data_out(spi_mem_data_out),
        .cmd_wr_en(spi_cmd_wr_en), .cmd_valid(spi_cmd_valid), .cmd_sector(spi_cmd_sector),
        .cmd_host_address(spi_cmd_host_address),
        .miso_pin(miso_pin), .mosi_pin(mosi_pin), .sck_pin(sck_pin), .cs_pin(cs_pin), .debug(spi_debug));

    reg test_read_pass;
    reg test_write_pass;
    reg test_done;
    reg [3:0] test_state;
    reg [3:0] test_tag;
    reg [8:0] test_x;
    reg [31:0] test_sector;

    assign led = ~{spi_card_is_init, spi_card_is_v1, spi_card_is_sdhc, test_read_pass, test_write_pass, test_done };

    // debugger
    reg [7:0] test_y;

    // once you see 00 FF you know you're back at byte 0 (bottom of wire assignment) since
    // no other byte can be FF.
    localparam done_msg_bytes = 8 + 8;
    wire [(done_msg_bytes*8)-1:0] done_msg = {
                8'hFF,
                8'h00,
                1'b0, test_sector[6:0],
                5'b0, test_done, test_read_pass, test_write_pass,
                
                4'b0, test_state,
                4'b0, test_tag,
                6'b0, test_x[8:7],
                1'b0, test_x[6:0],
                spi_debug                                   // 8-bytes, 64-bits
            };
    reg [(done_msg_bytes*8)-1:0] done_msg_l;
 
   always @(posedge pll_clk) begin
        if (!rst_n) begin
            uart_tx_start   <= 0;
            uart_rx_read    <= 0;
            uart_tx_data_in <= 0;
            test_y          <= 0;
            done_msg_l      <= 0;
        end else begin
            if (uart_rx_read) begin
                uart_rx_read <= 1'b0;
            end else begin
                if (uart_rx_ready) begin
                    uart_rx_read <= 1'b1;
                end
            end

            if (uart_tx_start) begin
                uart_tx_start <= 1'b0;
            end else begin
                if (!uart_tx_fifo_full) begin
                    uart_tx_start    <= 1'b1;
                    uart_tx_data_in  <= done_msg_l[(test_y * 8) +: 8];
                    if (test_y == (done_msg_bytes-1)) begin
                        done_msg_l <= done_msg;
                    end
                    test_y           <= (test_y == (done_msg_bytes-1)) ? 0 : (test_y + 1'b1);
                end
            end
        end
    end

    localparam
        STATE_INIT_WAIT = 0,
        STATE_DELAY = 1,
        STATE_DELAY2 = 2,
        STATE_READY = 3,
        STATE_ISSUE_READ = 4,
        STATE_TEST_READ_TOP = 5,
        STATE_TEST_READ_CHK = 6,
        STATE_ISSUE_WRITE = 7,
        STATE_WRITE_DONE = 8,
        STATE_DONE = 9;

    always @(posedge pll_clk) begin
        if (!rst_n) begin
            test_read_pass       <= 0;
            test_write_pass      <= 0;
            test_done            <= 0;
            test_state           <= 0;
            test_tag             <= 0;
            test_x               <= 0;
            test_sector          <= 0;
            spi_cmd_valid        <= 0;
            spi_cmd_wr_en        <= 0;
            spi_cmd_host_address <= 0;
            host_mem_wr_en       <= 0;
            host_mem_addr        <= 0;
            host_mem_data_in     <= 0;
            test_rom_addr        <= 0;
        end else begin
            case(test_state)
                STATE_INIT_WAIT:
                    begin
                        if (spi_card_is_init) begin
                            test_state <= STATE_ISSUE_READ;
                        end
                    end
                STATE_ISSUE_READ:
                    begin
                        spi_cmd_valid        <= 1;
                        spi_cmd_host_address <= 0;
                        spi_cmd_sector       <= test_sector;
                        spi_cmd_wr_en        <= 0;
                        test_state           <= STATE_READY;
                        test_tag             <= STATE_TEST_READ_TOP;
                    end
                STATE_TEST_READ_TOP:
                    begin
                        host_mem_addr <= {2'b00, test_x};
                        test_rom_addr <= test_x;
                        test_x        <= test_x + 1;
                        test_state    <= STATE_DELAY;
                        test_tag      <= STATE_TEST_READ_CHK;
                    end
                STATE_TEST_READ_CHK:
                    begin
                        test_state <= STATE_TEST_READ_TOP;
                        if (test_x == 0) begin
                            test_state <= STATE_ISSUE_WRITE;
                        end
                        if (host_mem_data_out != test_rom_dout) begin
                            test_state <= STATE_DONE;
                            test_tag   <= test_state;
                        end
                    end
                STATE_ISSUE_WRITE:
                    begin
                        test_read_pass       <= 1;
                        spi_cmd_valid        <= 1;
                        spi_cmd_host_address <= 0;
                        spi_cmd_sector       <= test_sector + 1'b1;
                        spi_cmd_wr_en        <= 1;
                        test_state           <= STATE_READY;
                        test_tag             <= STATE_WRITE_DONE;
                    end
                STATE_WRITE_DONE:
                    begin
                        test_write_pass      <= 1;
                        test_state           <= STATE_DONE;
                    end

                STATE_DONE:
                    begin
                        spi_cmd_valid   <= 1'b0;
                        test_done       <= 1;
                        if (uart_rx_read) begin
                            test_sector     <= test_sector + 1'b1;
                            test_state      <= STATE_INIT_WAIT;
                            test_read_pass  <= 0;
                            test_write_pass <= 0;
                            test_done       <= 0;
                        end
                    end

                STATE_DELAY:
                    begin
                        test_state <= STATE_DELAY2;
                    end
                STATE_DELAY2:
                    begin
                        test_state    <= test_tag;
                    end
                STATE_READY:
                    begin
                        if (spi_error != `SPISD_ERR_OK) begin
                            test_state <= STATE_DONE;
                        end else begin
                            if (spi_ready) begin
                                spi_cmd_valid <= 0;
                            end else if (!spi_ready && !spi_cmd_valid) begin
                                // only jump out after spisd goes idle.
                                test_state    <= test_tag;
                            end
                        end
                    end
            endcase
        end
    end
endmodule