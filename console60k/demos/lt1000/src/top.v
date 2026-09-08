`default_nettype none

`define FREQ 50_000

module top
(
    input wire clk,

    // UART
    inout wire [63:0] gpio
);
    // UART is on SD1,PMOD3
    wire uart_rx;
    wire uart_tx;

    // RX pin is last on BOT row
    assign gpio[63] = 1'bz;
    assign uart_rx = gpio[63];
    // TX pin is next to RX on BOT row
    assign gpio[62] = uart_tx;

    reg rst_n = 0;
    always @(posedge clk) begin
        rst_n <= 1;
    end


    lt1000soc #(
        .CORE_FREQ_KHZ(`FREQ)
    ) lt1000soc
    (
        .rst_n(rst_n), .core_clk(clk), .vga_clk(clk),

        .uart_rx(uart_rx), .uart_tx(uart_tx)
    );
endmodule