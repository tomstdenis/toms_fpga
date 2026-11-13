`default_nettype none
module top(
    input wire clk,
    input wire uart_rx,
    output wire uart_tx,
    output reg [1:0] vga_r,
    output reg [1:0] vga_g,
    output reg [1:0] vga_b,
    output reg vga_h_pulse,
    output reg vga_v_pulse,
    output reg led_r
);
    localparam
        USE_COLOR = 1,
        VT100_APPLE2_MODE = 0,  // set to 1 to enable 40x50 text mode which we can use for apple2 40col and LRG modes
        VT100_DEF_XDBL    = VT100_APPLE2_MODE ? 1 : 0,
        VT100_DEF_YDBL    = VT100_APPLE2_MODE ? 1 : 1;

    reg [3:0] rstcnt = 4'b0000;
    wire rst_n;
    assign rst_n = rstcnt[3];

    // dropped the PLL for this demo since it native runs at 27MHz and the PLL can't target 25MHz anyways...
    wire pll_clk = clk;
	wire pll_locked = 1'b1;

//    Gowin_PLL vgatimmer(
//        .clkin(clk), //input  clkin
//        .clkout0(pll_clk) //output  clkout0
//    );

    always @(posedge pll_clk) begin
		if (pll_locked) begin
			rstcnt <= {rstcnt[2:0], 1'b1};
		end
        led_r <= uart_rx;
    end

    // we're using a RGB222 so we need to reduce RGB444
    wire [3:0] vga_r_f;
    wire [3:0] vga_g_f;
    wire [3:0] vga_b_f;
    wire       vga_h_pulse_f;
    wire       vga_v_pulse_f;
    wire       vga_active_f;

    // only use top two bits to make 64-colour palette
    always @(posedge pll_clk) begin
        vga_r       <= vga_r_f[3:2];
        vga_g       <= vga_g_f[3:2];
        vga_b       <= vga_b_f[3:2];
        vga_h_pulse <= vga_h_pulse_f;
        vga_v_pulse <= vga_v_pulse_f;
    end

    // vt100 emulator
    // This uses the uart pins (uart_rx/uart_tx) and then drives port A of the DP video memory
    vt100 #(
        .VT100_FREQ(50_000_000),
        .VT100_ECHO(0),
        .USE_COLOR(USE_COLOR),
        .INDEX_BITS(12),
        .CLK_DIV(1),                    // at 50MHz we need to divide the VGA timing by 2
        .X_FETCH_DELAY(1),              // also memory fetches happen in half the time from the perspective of the VGA text driver
        .DEF_X_DBL(VT100_DEF_XDBL),
        .DEF_Y_DBL(VT100_DEF_YDBL))
    thefuture
    (
        .clk(pll_clk), .rst_n(rst_n),
        .uart_tx(uart_tx), .uart_rx(uart_rx),                                                   // UART
        .vga_r(vga_r_f), .vga_g(vga_g_f), .vga_b(vga_b_f),                                      // VGA RGB output
        .vga_h_pulse(vga_h_pulse_f), .vga_v_pulse(vga_v_pulse_f), .vga_active(vga_active_f)
    );  

endmodule

`include "vt100/vt100.v"