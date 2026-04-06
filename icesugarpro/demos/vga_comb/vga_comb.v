`timescale 1ns/1ps
`default_nettype none

module top(input clk, output [3:0] vga_r, output [3:0] vga_g, output [3:0] vga_b, output vga_h_pulse, output vga_v_pulse);

    reg [3:0] rstcnt = 4'b0;
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
	
	assign vga_r = 4'b0;
	assign vga_g = 4'b0;
	assign vga_b = 4'b0;

	vga_timing vga(
		.clk(pll_clk),
		.rst(rst_n),
		.x(vga_x),
		.y(vga_y),
		.h_sync(vga_h_sync),
		.v_sync(vga_v_sync),
		.active_video(vga_active));

endmodule
