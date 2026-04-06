`timescale 1ns/1ps
`default_nettype none

module top(input clk, output reg [3:0] vga_r, output reg [3:0] vga_g, output reg [3:0] vga_b, output vga_h_pulse, output vga_v_pulse);

    reg [3:0] rstcnt = 4'b0000;
    wire rst_n;
    assign rst_n = rstcnt[3];

    wire pll_clk;
	wire pll_locked;

	pll1 pll(.clkin(clk), .clkout0(pll_clk), .locked(pll_locked));
	
    always @(posedge pll_clk) begin
		if (pll_locked) begin
			rstcnt <= {rstcnt[2:0], 1'b1};
		end
    end

	// bit widths are for 640x480 VGA
	wire [9:0] vga_x;
	wire [9:0] vga_y;
	wire vga_h_sync;
	wire vga_v_sync;
	wire vga_active;
	
	assign vga_h_pulse = vga_h_sync;
	assign vga_v_pulse = vga_v_sync;

	vga_timing vga(
		.clk(pll_clk),
		.rst_n(rst_n),
		.x(vga_x),
		.y(vga_y),
		.h_sync(vga_h_sync),
		.v_sync(vga_v_sync),
		.active_video(vga_active));

	wire [9:0] x = vga_x + 1;
	wire [9:0] y = vga_y + 1;
	reg [7:0] symbol;
	wire text_out;
	reg [23:0] counter = 0;
	
	vga_8x8_font_256 font(.symbol(symbol), .x(vga_x[2:0]), .y(vga_y[2:0]), .out(text_out));	
	
	always @(posedge pll_clk) begin
		counter <= counter + 1;
		if (vga_active) begin
			case({x[9:3], y[9:3]}) // case of x and y text coordinates
				default: symbol <= 8'h20; // space
				
				// first row (start on row 6/col 6)
				{7'd5, 7'd5}: symbol <= 8'h54; // T
				{7'd6, 7'd5}: symbol <= 8'h6F; // o
				{7'd7, 7'd5}: symbol <= 8'h6d; // m
				// space
				{7'd9, 7'd5}: symbol <= 8'h77; // w
				{7'd10, 7'd5}: symbol <= 8'h61; // a
				{7'd11, 7'd5}: symbol <= 8'h73; // s
				// space
				{7'd13, 7'd5}: symbol <= 8'h68; // h
				{7'd14, 7'd5}: symbol <= 8'h65; // e
				{7'd15, 7'd5}: symbol <= 8'h72; // r
				{7'd16, 7'd5}: symbol <= 8'h65; // e
				// space
				{7'd17, 7'd5}: symbol <= counter[23:16]; // counter 
				
			endcase
		end
	end
	
	always @(*) begin
		vga_r = 0;
		vga_g = 0;
		vga_b = 0;
		
		if (vga_active) begin
			{vga_r, vga_g, vga_b} = text_out ? 12'b1111_1111_1111 : 12'b0;
		end
	end

endmodule
