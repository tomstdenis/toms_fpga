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

    localparam
        LED_CARD_INIT = 0,
        LED_READ_PASS = 1,
        LED_WRITE_PASS = 2,
        LED_DONE = 3;

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
    wire [15:0] baud_div = (`FREQ * 1_000_000) / 115_200;
    reg uart_tx_start;
    reg [7:0] uart_tx_data_in;
    wire uart_tx_fifo_empty;
    wire uart_tx_fifo_full;
    reg uart_rx_read;
    wire uart_rx_ready;
    wire [7:0] uart_rx_byte;

    uart #(.FIFO_DEPTH(4), .RX_ENABLE(1), .TX_ENABLE(1)) spi_uart(
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

    test_data spi_testdata(
        .dout(test_rom_dout), //output [7:0] dout
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
    reg  spi_cmd_wr_en;
    reg  spi_cmd_valid;
    reg [31:0] spi_cmd_sector;
    reg [10:0] spi_cmd_host_address;

    spisddma #(.CLK_FREQ_MHZ(`FREQ), .READ_CRC_CHK(0), .FAST_CLK(24_000_000)) (
        .clk(pll_clk), .rst_n(rst_n),
        .ready(spi_ready), .error(spi_error),
        .card_is_v1(spi_card_is_v1), .card_is_init(spi_card_is_init),
        .host_mem_addr(spi_mem_addr), .host_mem_wr_en(spi_mem_wr_en),
        .host_mem_data_in(spi_mem_data_in), .host_mem_data_out(spi_mem_data_out),
        .cmd_wr_en(spi_cmd_wr_en), .cmd_valid(spi_cmd_valid), .cmd_sector(spi_cmd_sector),
        .cmd_host_address(spi_cmd_host_address),
        .miso_pin(miso_pin), .mosi_pin(mosi_pin), .sck_pin(sck_pin), .cs_pin(cs_pin));

    reg test_read_pass;
    reg test_write_pass;
    reg test_done;
    reg [3:0] test_state;
    reg [3:0] test_tag;
    reg [8:0] test_x;

    assign led = ~{spi_card_is_init, spi_card_is_v1, test_read_pass, test_write_pass, test_done, 1'b0 };

    localparam
        STATE_INIT_WAIT = 0,
        STATE_DELAY = 1,
        STATE_READY = 2,
        STATE_ISSUE_READ = 3,
        STATE_TEST_READ_TOP = 4,
        STATE_TEST_READ_CHK = 5,
        STATE_ISSUE_WRITE = 6,
        STATE_WRITE_DONE = 7,
        STATE_DONE = 8;

    always @(posedge pll_clk) begin
        if (!rst_n) begin
            test_read_pass <= 0;
            test_write_pass <= 0;
            test_done <= 0;
            test_state <= 0;
            test_tag <= 0;
            test_x <= 0;
            spi_cmd_valid <= 0;
            host_mem_wr_en <= 0;
            host_mem_addr <= 0;
            test_rom_addr <= 0;
            uart_tx_start <= 0;
            uart_rx_read <= 0;
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
                        spi_cmd_valid <= 1;
                        spi_cmd_host_address <= 0;
                        spi_cmd_sector <= 0;
                        spi_cmd_wr_en <= 0;
                        test_state <= STATE_READY;
                        test_tag   <= STATE_TEST_READ_TOP;
                    end
                STATE_TEST_READ_TOP:
                    begin
                        host_mem_addr <= test_x;
                        test_rom_addr <= test_x;
                        test_x <= test_x + 1;
                        test_state <= STATE_DELAY;
                        test_tag  <= STATE_TEST_READ_CHK;
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
                        test_read_pass <= 1;
                        spi_cmd_valid <= 1;
                        spi_cmd_host_address <= 0;
                        spi_cmd_sector <= 1;
                        spi_cmd_wr_en <= 1;
                        test_state <= STATE_READY;
                        test_tag   <= STATE_WRITE_DONE;
                    end
                STATE_WRITE_DONE:
                    begin
                        test_write_pass <= 1;
                        test_state <= STATE_DONE;
                    end
                STATE_DONE:
                    begin
                        // uart stuff later...
                    end

                STATE_DELAY:
                    begin
                        test_state <= test_tag;
                    end
                STATE_READY:
                    begin
                        if (spi_error != 0) begin
                            test_state <= STATE_DONE;
                        end else begin
                            if (spi_ready) begin
                                spi_cmd_valid <= 0;
                                test_state <= test_tag;
                            end
                        end
                    end
            endcase
        end
    end
endmodule