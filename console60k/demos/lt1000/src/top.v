`default_nettype none

`define FREQ 50_000

module top
(
    input wire clk,

    // rest of pins
    inout wire [61:0] gpio,

    // UART
    input wire uart_rx,
    output wire uart_tx
);
    reg rst_n = 0;
    always @(posedge clk) begin
        rst_n   <= 1;
    end


    lt1000soc #(
        .CORE_FREQ_KHZ(`FREQ),
        .UART_BAUD(1_000_000)
    ) lt1000soc
    (
        .rst_n(rst_n), .core_clk(clk), .vga_clk(clk),
        .uart_rx(uart_rx), .uart_tx(uart_tx)
    );
endmodule