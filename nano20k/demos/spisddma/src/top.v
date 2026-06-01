`include "spisddma.vh"
`define FREQ 48

module top(
    input wire clk,
    input wire rx_pin,
    output wire tx_pin,
    output wire led[5:0],
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


endmodule