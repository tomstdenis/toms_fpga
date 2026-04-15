`timescale 1ns/1ps
`default_nettype none

module top(input wire clk, output reg [3:0] vga_r, output reg [3:0] vga_g, output reg [3:0] vga_b, output wire  vga_h_pulse, output wire vga_v_pulse);

    reg [3:0] rstcnt = 4'b0000;
    wire rst_n;
    assign rst_n = rstcnt[3];

    wire pll_clk;
	wire pll_locked = 1'b1;

    Gowin_PLL ticktock(
        .clkin(clk), //input  clkin
        .clkout0(pll_clk), //output  clkout0
        .mdclk() //input  mdclk
    );

    always @(posedge pll_clk) begin
		if (pll_locked) begin
			rstcnt <= {rstcnt[2:0], 1'b1};
		end
    end

	// bit widths are for 640x480 VGA
	wire [10:0] vga_x;
	wire [9:0] vga_y;
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

	wire [7:0] symbol;
	wire text_out;
	
/*
	// font rom (note we scale y by 2 to fit the 80x25 chars onto 640x480 a bit nicer)
	// this module takes in the symbol value and x/y pixel position relative to the top left corner of the symbol
	vga_8x8_font_256 font(.symbol(symbol), .x(vga_x[2:0]), .y(vga_y[3:1]), .out(text_out));	
*/

    // on Gowin a Shadow ROM is better as it's both faster and smaller (and faster to compile)
    wire [7:0] font_dout;                           // output of rom
    wire [10:0] font_ad = {symbol, vga_y[3:1]};     // address into the rom, it's 11 bits of which the top 8 are the symbol and bottom 3 are the row
    assign text_out = font_dout[7 - vga_x[2:0]];    // bit of output indexed from the ROM output

    // our 256 symbol 8x8 CP437 font
    Gowin_ROM16 madamme_font(
        .dout(font_dout), //output [7:0] dout
        .ad(font_ad) //input [10:0] ad
    );

	reg [10:0] wr_addr;			// our write port to fill it
	reg [7:0] wr_data;
	reg wr_en;
	
	wire [10:0] rd_addr;		// the read port the vga_text_driver reads from
	wire [7:0] rd_data;
	
    // A semi dual ported memory which we can write(portA) and the VGA can read(portB)
    Gowin_SDPB mr_memory(
        .dout(rd_data), //output [7:0] dout
        .clka(pll_clk), //input clka
        .cea(wr_en), //input cea                    // write enable is clock enable A (cea)
        .clkb(pll_clk), //input clkb
        .ceb(1'b1), //input ceb
        .oce(1'b1), //input oce // (leave this as 1 if not pipelining)
        .reset(~rst_n), //input reset
        .ada(wr_addr), //input [10:0] ada
        .din(wr_data), //input [7:0] din
        .adb(rd_addr) //input [10:0] adb
    );

	// VGA text mode driver, defaults to 80x25 using an 8x8 font
	// notice we're scaling the font by 2 so we change the height to 16 here
	vga_text_driver #(.FONTHEIGHT(16)) textdrv(
		.clk(pll_clk), .rst_n(rst_n),
		.x(vga_x), .y(vga_y), .active_video(vga_active),
		.rd_addr(rd_addr), .rd_data(rd_data),
		.symbol(symbol), .lrg_mode(1'b0));

	// So the pipe is vga() produces the timing that
	// textdrv() uses produces the next 'symbol' that
	// font() uses to produce the next black/white signal fed to the VGA RGB output
	
	reg [23:0] counter = 0;
	always @(posedge pll_clk) begin
		if (!rst_n) begin
			wr_addr <= -1;
			wr_data <= 0;
			wr_en <= 1;
		end else begin
			counter <= counter + 1;
			// advance to next address
			wr_addr <= wr_addr + 1;
			wr_data <= 8'h20; // default space
			if (wr_addr == 2000) begin
				// we hit the end of the text buffer turn writes off
				wr_en <= 0;
			end
			
			// what value to write in the next cycle
			case (wr_addr + 1)				
				// first row (start on row 6/col 6)
				80*5 + 5: wr_data <= 8'h54; // T			//80 * 5 + 5 is TEXTCOLS * vga_y/FONTHEIGHT + vga_x/FONTWIDTH
				80*5 + 6: wr_data <= 8'h6F; // o
				80*5 + 7: wr_data <= 8'h6d; // m
				// space
				80*5 + 9: wr_data <= 8'h77; // w
				80*5 + 10: wr_data <= 8'h61; // a
				80*5 + 11: wr_data <= 8'h73; // s
				// space
				80*5 + 13: wr_data <= 8'h68; // h
				80*5 + 14: wr_data <= 8'h65; // e
				80*5 + 15: wr_data <= 8'h72; // r
				80*5 + 16: wr_data <= 8'h65; // e
				// space 
				80*5 + 18: wr_data <= 8'h61; // a
				80*5 + 19: wr_data <= 8'h6e; // n
				80*5 + 20: wr_data <= 8'h64; // d
				// space
				80*5 + 22: wr_data <= 8'h6d; // m
				80*5 + 23: wr_data <= 8'h6f; // o
				// space
				80*5 + 25: wr_data <= 8'h69; // i
				80*5 + 26: wr_data <= 8'h73; // s
				//space				
				80*5 + 28: wr_data <= 8'h63; // c
				80*5 + 29: wr_data <= 8'h6f; // o
				80*5 + 30: wr_data <= 8'h6f; // o
				80*5 + 31: wr_data <= 8'h6c; // l			
			endcase

			// put random data on lines 7 down
			if (wr_addr + 1 > 7*80) begin
				wr_data <= counter[7:0];
			end
		end
	end
	
	always @(*) begin
		vga_r = 0;
		vga_g = 0;
		vga_b = 0;
		
		if (vga_active) begin
			{vga_r, vga_g, vga_b} = text_out ? 12'b1111_1111_1111 : 12'b0;
//			{vga_r, vga_g, vga_b} = text_out ? 12'b1111_0000_0000 : 12'b0;
		end
	end

endmodule
