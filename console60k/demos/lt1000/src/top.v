`default_nettype none
`define FREQ 110_000

// use DVI output, uncomment to use the VGA pins
`define USE_DVI


module top
(
    input wire clk,

    // rest of pins
    inout wire [47:0] gpio,

    // SPI
    output wire [3:0] spi_cs_pin,
    output wire spi_sck_pin,
    output wire spi_mosi_pin,
    input wire  spi_miso_pin,

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

    // DVI
    output wire       tmds_clk_n,
    output wire       tmds_clk_p,
    output wire [2:0] tmds_d_n,
    output wire [2:0] tmds_d_p,

    // UART
    input wire uart_rx,
    output wire uart_tx
);

    // debug sigrok on a gpio [47:40]
    reg [6:0] mon;
    assign gpio[46:40] = mon;
    always @(posedge core_clk) begin
        mon[0] <= spi_sck_pin;
        mon[1] <= spi_miso_pin;
        mon[2] <= spi_mosi_pin;
        mon[3] <= spi_cs_pin[0];
        mon[4] <= spi_cs_pin[1];
        mon[5] <= spi_cs_pin[2];
        mon[6] <= spi_cs_pin[3];
    end

    wire core_clk;
    wire vga_clk;
    wire dvi_serial_clk;

    lt1000clk daysofourlives(
        .clkin(clk), //input  clkin
        .clkout0(core_clk), //output  clkout0
        .clkout1(vga_clk), //output  clkout1
        .clkout2(dvi_serial_clk)
    );

    reg crst_n;
    initial crst_n = 1'b0;
    always @(posedge core_clk) begin
        crst_n <= 1'b1;
    end

    reg vrst_n;
    initial vrst_n = 1'b0;
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
    wire       ltvga_h_blank;
    wire       ltvga_v_blank;

`ifndef USE_DVI
    always @(posedge vga_clk) begin
        vga_r       <= ltvga_r[3:2];
        vga_g       <= ltvga_g[3:2];
        vga_b       <= ltvga_b[3:2];
        vga_h_pulse <= ltvga_h_pulse;
        vga_v_pulse <= ltvga_v_pulse;
    end
`else
    reg [7:0] dvi_r;
    reg [7:0] dvi_g;
    reg [7:0] dvi_b;
    reg       dvi_vs;
    reg       dvi_hs;
    reg       dvi_de;

    always @(posedge vga_clk) begin
        dvi_r  <= {ltvga_r, ltvga_r};
        dvi_g  <= {ltvga_g, ltvga_g};
        dvi_b  <= {ltvga_b, ltvga_b};
        dvi_vs <= ltvga_v_pulse;
        dvi_hs <= ltvga_h_pulse;
        dvi_de <= !(ltvga_h_blank | ltvga_v_blank);
    end

	DVI_TX MrFancyPants(
		.I_rst_n(vrst_n), //input I_rst_n
		.I_serial_clk(dvi_serial_clk), //input I_serial_clk
		.I_rgb_clk(vga_clk), //input I_rgb_clk
		.I_rgb_vs(dvi_vs), //input I_rgb_vs
		.I_rgb_hs(dvi_hs), //input I_rgb_hs
		.I_rgb_de(dvi_de), //input I_rgb_de
		.I_rgb_r(dvi_r), //input [7:0] I_rgb_r
		.I_rgb_g(dvi_g), //input [7:0] I_rgb_g
		.I_rgb_b(dvi_b), //input [7:0] I_rgb_b
		.O_tmds_clk_p(tmds_clk_p), //output O_tmds_clk_p
		.O_tmds_clk_n(tmds_clk_n), //output O_tmds_clk_n
		.O_tmds_data_p(tmds_d_p), //output [2:0] O_tmds_data_p
		.O_tmds_data_n(tmds_d_n) //output [2:0] O_tmds_data_n
	);
`endif


    lt1000soc #(
        .CORE_FREQ_KHZ(`FREQ),
        .UART_BAUD(1_000_000)
    ) lt1000soc
    (
        .core_rst_n(crst_n), .core_clk(core_clk), .vga_rst_n(vrst_n), .vga_clk(vga_clk),
        .uart_rx(uart_rx), .uart_tx(uart_tx),

        // SPI
        .spi_cs_pin(spi_cs_pin), .spi_sck_pin(spi_sck_pin), .spi_mosi_pin(spi_mosi_pin), .spi_miso_pin(spi_miso_pin),

        // PSRAM
        .psram_sio_din(psram_sio_din), .psram_sio_dout(psram_sio_dout), .psram_sio_en(psram_sio_en),
        .psram_cs_pin(psram_cs_pin), .psram_sck_pin(psram_sck_pin),

        // GPIO
        .gpio_din(gpio_din), .gpio_dout(gpio_dout), .gpio_oe(gpio_oe),

        // VGA
        .vga_r(ltvga_r), .vga_g(ltvga_g), .vga_b(ltvga_b), .vga_h_pulse(ltvga_h_pulse), .vga_v_pulse(ltvga_v_pulse),
        .vga_h_blank(ltvga_h_blank), .vga_v_blank(ltvga_v_blank)
    );
endmodule