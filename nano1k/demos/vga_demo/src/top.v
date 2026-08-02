`default_nettype none
module top(
    input wire clk,
    input wire uart_rx,
    output wire uart_tx,
    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b,
    output wire vga_h_pulse,
    output wire vga_v_pulse
);
    reg [3:0] rstcnt = 4'b0000;
    wire rst_n;
    assign rst_n = rstcnt[3];

    // dropped the PLL for this demo since it native runs at 27MHz and the PLL can't target 25MHz anyways...
    wire pll_clk = clk;
	wire pll_locked = 1'b1;

    always @(posedge pll_clk) begin
		if (pll_locked) begin
			rstcnt <= {rstcnt[2:0], 1'b1};
		end
    end

	// bit widths are for 640x480 VGA
	wire [10:0] vga_x;
	wire [10:0] vga_y;
	wire vga_h_sync;
	wire vga_v_sync;
	wire vga_active;
	
	assign vga_h_pulse = vga_h_sync;
	assign vga_v_pulse = vga_v_sync;

	// this module produces the VGA timing signals other modules depend on
	vga_timing vga(
		.clk(pll_clk),
		.rst_n(rst_n),
		.x(vga_x),
		.y(vga_y),
		.h_sync(vga_h_sync),
		.v_sync(vga_v_sync),
		.active_video(vga_active));

    // we need to figure out the font info for the /next/ cycle since this isn't combinatorial
	wire [15:0] symbol;
	wire text_out;

    wire [10:0] vga_y_p1 = (vga_y + (vga_x == 799 ? 1'b1 : 1'b0));
    wire [7:0] font_dout;                           // output of rom
    wire [10:0] font_ad = {symbol[7:0], vga_y_p1[3:1]};     // address into the rom, it's 11 bits of which the top 8 are the symbol and bottom 3 are the row
    assign text_out = font_dout[7 - vga_x[2:0]];    // bit of output indexed from the ROM output

    // our 256 symbol 8x8 CP437 font
    Gowin_pROM madamme_font(
        .dout(font_dout), //output [7:0] dout
        .ad(font_ad), //input [10:0] ad
        .clk(pll_clk), //input clk
        .oce(1'b1), //input oce
        .ce(1'b1), //input ce
        .reset(~rst_n)
    );

    // video memory (16 bit wide, 2048 deep for a 80x25 with attribute bytes)
    wire [15:0] mem_dout_a;
    wire mem_wr_en_a;
    wire [10:0] mem_addr_a;
    wire [15:0] mem_din_a;

    wire [15:0] mem_dout_b;
    wire [10:0] mem_addr_b;
	
    Gowin_DPB vt100_mem(
        // VT100
        .douta(mem_dout_a), //output [15:0] douta
        .clka(pll_clk), //input clka
        .ocea(1'b1), //input ocea
        .cea(1'b1), //input cea
        .reseta(~rst_n), //input reseta
        .wrea(mem_wr_en_a), //input wrea
        .ada(mem_addr_a), //input [10:0] ada
        .dina(mem_din_a), //input [15:0] dina

        // text driver
        .doutb(mem_dout_b), //output [15:0] doutb
        .clkb(pll_clk), //input clkb
        .oceb(1'b1), //input oceb
        .ceb(1'b1), //input ceb
        .resetb(~rst_n), //input resetb
        .wreb(1'b0), //input wreb
        .adb(mem_addr_b), //input [10:0] adb
        .dinb(16'b0) //input [15:0] dinb
    );

	// VGA text mode driver, defaults to 80x25 using an 8x8 font
	// notice we're scaling the font by 2 so we change the height to 16 here
	vga_text_driver #(.FONTHEIGHT(16), .X_FETCH_DELAY(2), .SYMBOL_BITS(16)) textdrv(
		.clk(pll_clk), .rst_n(rst_n),
		.x(vga_x), .y(vga_y), .active_video(vga_active),
		.rd_addr(mem_addr_b), .rd_data(mem_dout_b),
		.symbol(symbol), .lrg_mode(1'b0));

    // vt100 emulator
    // This uses the uart pins (uart_rx/uart_tx) and then drives port A of the DP video memory
    vt100 thefuture(
        .clk(pll_clk), .rst_n(rst_n),
        .uart_tx(uart_tx), .uart_rx(uart_rx),                                                                // uart
        .mem_addr_a(mem_addr_a), .mem_din_a(mem_din_a), .mem_dout_a(mem_dout_a), .mem_wr_en_a(mem_wr_en_a),  // framebuffer
        .text_out(text_out), .symbol(symbol),                                                                                     // text driver output symbol
        .vga_active(vga_active), .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b));                               // vga RGB output

endmodule