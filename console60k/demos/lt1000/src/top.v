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

    wire [31:0] gpio_dout;
    wire [31:0] gpio_din;
    wire [31:0] gpio_oe;

    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : gpio_inputs
            assign gpio[i] = gpio_oe[i] ? gpio_dout[i] : 1'bz;
        end
    endgenerate
    assign gpio_din = gpio[31:0];

    lt1000soc #(
        .CORE_FREQ_KHZ(`FREQ),
        .UART_BAUD(1_000_000)
    ) lt1000soc
    (
        .rst_n(rst_n), .core_clk(clk), .vga_clk(clk),
        .uart_rx(uart_rx), .uart_tx(uart_tx),
        .gpio_din(gpio_din), .gpio_dout(gpio_dout), .gpio_oe(gpio_oe)
    );
endmodule