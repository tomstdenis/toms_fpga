/* Text mode driver

The purpose of this module is given a 2KB BRAM memory it produces
one output 'symbol' in step with the VGA signalling so the font
rom can produce the signal to output

*/
`timescale 1ns/1ps
`default_nettype none

// TODO: Currently only powers of two are supported for the Font dimensions
module vga_text_driver #(
	parameter H_TOTAL=640,									 		// visible width		
	parameter V_TOTAL=480,											// visible height
	parameter TEXTCOLS=80,											// number of text columns
	parameter TEXTROWS=25,											// number of text rows
	parameter FONTWIDTH=8,											// font width in pixels
	parameter FONTHEIGHT=8											// font height in pixels
)
(
	input wire		   clk,											// Pixel clock
	input wire		   rst_n,										// active low reset

// VGA signalling
    input wire  [$clog2(H_TOTAL):0]  x,								// Pixel X coordinate
    input wire  [$clog2(V_TOTAL):0]  y,								// Pixel Y coordinate
    input wire        active_video,									// is the video active (not in blanking region)

// Memory
	output reg [$clog2(TEXTCOLS*TEXTROWS):0] rd_addr,				// read address, assumes data is available with 1 wait state
	input wire [7:0] rd_data,										// read data
	
// symbol for font driver
	output reg [7:0] symbol											// symbol to feed font rom
);	
	// which character position are we at
	wire [$clog2(H_TOTAL):0] col = x / FONTWIDTH;
	wire [$clog2(V_TOTAL):0] row = y / FONTHEIGHT;

	// Combinatorial address calculation is much safer
	wire [$clog2(TEXTCOLS*TEXTROWS):0] current_addr = (row * TEXTCOLS) + col;

	always @(posedge clk) begin
		// Latch symbol at the last column of font
		if (row < TEXTROWS && col < TEXTCOLS) begin
			rd_addr <= current_addr;
			if (x[$clog2(FONTWIDTH)-1:0] == (FONTWIDTH-1)) begin
				symbol <= rd_data;
			end
		end else begin
			symbol <= 8'h20;
		end
	end
endmodule
