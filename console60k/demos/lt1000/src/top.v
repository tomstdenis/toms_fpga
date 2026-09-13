`default_nettype none

`define FREQ 100_000

module top
(
    input wire clk,

    // rest of pins
    inout wire [61:0] gpio,

    // PSRAM
    output wire psram_sck_pin,
    output wire psram_cs_pin,
    inout wire [3:0] psram_sio,

    // VGA
    output reg [1:0] vga_r,
    output reg [1:0] vga_g,
    output reg [1:0] vga_b,
    output reg       vga_h_pulse,
    output reg       vga_v_pulse,

    // UART
    input wire uart_rx,
    output wire uart_tx
);
    wire core_clk;
    wire vga_clk;

    lt1000clk daysofourlives(
        .clkin(clk), //input  clkin
        .clkout0(core_clk), //output  clkout0
        .clkout1(vga_clk) //output  clkout1
    );

    reg crst_n;
    initial crst_n = 1'b0;
    always @(posedge core_clk) begin
        crst_n <= 1'b1;
    end

    reg vrst_n;
    initial vrst_n = 4'b0000;
    always @(posedge vga_clk) begin
        vrst_n <= 1'b1;
    end

    // PSRAM
    wire [3:0] psram_sio_din;
    wire [3:0] psram_sio_dout;
    wire       psram_sio_en;
    assign psram_sio     = psram_sio_en ? psram_sio_dout : 4'bzzzz;
    assign psram_sio_din = psram_sio;

    // GPIO
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

    // VGA
    wire [3:0] ltvga_r;
    wire [3:0] ltvga_g;
    wire [3:0] ltvga_b;
    wire       ltvga_h_pulse;
    wire       ltvga_v_pulse;

    always @(posedge vga_clk) begin
        vga_r       <= ltvga_r[3:2];
        vga_g       <= ltvga_g[3:2];
        vga_b       <= ltvga_b[3:2];
        vga_h_pulse <= ltvga_h_pulse;
        vga_v_pulse <= ltvga_v_pulse;
    end

    lt1000soc #(
        .CORE_FREQ_KHZ(`FREQ),
        .UART_BAUD(1_000_000)
    ) lt1000soc
    (
        .core_rst_n(crst_n), .core_clk(core_clk), .vga_rst_n(vrst_n), .vga_clk(vga_clk),
        .uart_rx(uart_rx), .uart_tx(uart_tx),

        // PSRAM
        .psram_sio_din(psram_sio_din), .psram_sio_dout(psram_sio_dout), .psram_sio_en(psram_sio_en),
        .psram_cs_pin(psram_cs_pin), .psram_sck_pin(psram_sck_pin),

        // GPIO
        .gpio_din(gpio_din), .gpio_dout(gpio_dout), .gpio_oe(gpio_oe),

        // VGA
        .vga_r(ltvga_r), .vga_g(ltvga_g), .vga_b(ltvga_b), .vga_h_pulse(ltvga_h_pulse), .vga_v_pulse(ltvga_v_pulse)
    );
endmodule