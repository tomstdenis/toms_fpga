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

	always @(*) begin
		vga_r = 0;
		vga_g = 0;
		vga_b = 0;
		
		if (vga_active) begin
			// vertical division divide 480, 4 ways
			if (vga_y >= 120 && vga_y < 240) begin
				vga_r[3:2] = 2'b11;
			end
			if (vga_y >= 240 && vga_y < 360) begin
				vga_g[3:2] = 2'b11;
			end
			if (vga_y >= 360 && vga_y < 480) begin
				vga_b[3:2] = 2'b11;
			end
			
			// horizontal division divide 640, 4 ways
			if (vga_x >= 160 && vga_x < 320) begin
				vga_r[1:0] = 2'b11;
			end
			if (vga_x >= 320 && vga_x < 480) begin
				vga_g[1:0] = 2'b11;
			end
			if (vga_x >= 480 && vga_x < 640) begin
				vga_b[1:0] = 2'b11;
			end
		end

	end

	vga_timing vga(
		.clk(pll_clk),
		.rst_n(rst_n),
		.x(vga_x),
		.y(vga_y),
		.h_sync(vga_h_sync),
		.v_sync(vga_v_sync),
		.active_video(vga_active));

endmodule
