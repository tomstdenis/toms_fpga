/* 8x8 font with 256 symbols */
`timescale 1ns/1ps
`default_nettype none

module vga_8x8_font_256 (
	input wire [7:0] symbol,
	input wire [2:0] x,
	input wire [2:0] y,
	output reg out
);

	always @(*) begin
		case ({symbol, y, x})
`include "8x8_font_256.vh"
		default: out = 1'b0;
		endcase
	end
endmodule
