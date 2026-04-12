/* Text mode driver

The purpose of this module is given a 2KB BRAM memory it produces
one output 'symbol' in step with the VGA signalling so the font
rom can produce the signal to output

*/
`timescale 1ns/1ps
`default_nettype none

// TODO: Currently only powers of two are supported for the Font dimensions
module vga_text_driver #(
	parameter H_VISIBLE  = 640,									 		// visible width		
	parameter V_VISIBLE  = 480,											// visible height
    parameter V_TOTAL    = 525,
    parameter H_TOTAL    = 800,
	parameter TEXTCOLS   = 80,											// number of text columns
	parameter TEXTROWS   = 25,											// number of text rows
	parameter FONTWIDTH  = 8,											// font width in pixels
	parameter FONTHEIGHT = 8											// font height in pixels
)
(
	input wire		   clk,											// Pixel clock
	input wire		   rst_n,										// active low reset

// VGA signalling
    input wire  [$clog2(H_VISIBLE):0]  x,								// Pixel X coordinate
    input wire  [$clog2(V_VISIBLE):0]  y,								// Pixel Y coordinate
    input wire        active_video,									// is the video active (not in blanking region)
    input wire        lrg_mode,										// 0 == text CP437 mode, 1 == low res graphics mode

// Memory
	output reg [$clog2(TEXTCOLS*TEXTROWS):0] rd_addr,				// read address, assumes data is available with 1 wait state
	input wire [7:0] rd_data,										// read data
	
// symbol for font driver
	output reg [7:0] symbol											// symbol to feed font rom
);	

	// variables for text mode 
	// which character position are we at
	wire [$clog2(H_VISIBLE):0] text_col = x / FONTWIDTH;
	wire [$clog2(V_VISIBLE):0] text_row = y / FONTHEIGHT;

	// Combinatorial address calculation is much safer
	wire [$clog2(TEXTCOLS*TEXTROWS):0] text_current_addr = (text_row * TEXTCOLS) + text_col;
	
	// variables for lrg mode
	wire [$clog2(H_VISIBLE):0] lrg_col = x >> 4;
	wire [$clog2(V_VISIBLE):0] lrg_row = y >> 4;
	
	localparam
		LRG_COLS = H_VISIBLE >> 4,
		LRG_ROWS = V_VISIBLE >> 4;

	// Combinatorial address calculation is much safer
	wire [$clog2(LRG_COLS*LRG_ROWS):0] lrg_current_addr = (lrg_row * LRG_COLS) + lrg_col;

	always @(posedge clk) begin
		if (!rst_n) begin
			rd_addr <= 0;
		end else if (lrg_mode == 0) begin
			// text 80x25 mode
			if (text_row < TEXTROWS && text_col < TEXTCOLS) begin
				rd_addr <= text_current_addr + 1;
				// Latch symbol at the last column of font
				if (x[$clog2(FONTWIDTH)-1:0] == (FONTWIDTH-1)) begin
					symbol <= rd_data;
				end
			end else begin
				if (x == (H_TOTAL-3)) begin
					// set the next address 
					if (y >= (V_TOTAL-1)) begin
						rd_addr <= 0;
					end else begin
						if (y[$clog2(FONTHEIGHT)-1:0] == (FONTHEIGHT-1)) begin
							rd_addr <= (text_row * TEXTCOLS) + TEXTCOLS;
						end else begin
							rd_addr <= (text_row * TEXTCOLS);
						end
					end
				end else if (x == (H_TOTAL-1)) begin
					if (text_row >= TEXTROWS) begin
						symbol <= 8'h20;
					end else begin
						symbol <= rd_data;
					end
				end
			end
			if (active_video && y >= (TEXTROWS*FONTHEIGHT)) begin
				symbol <= 8'h20;
			end
		end else begin
			// lowres graphics mode
			if (lrg_row < LRG_ROWS && lrg_col < LRG_COLS) begin
				rd_addr <= lrg_current_addr + 1;
				if (x[3:0] == 4'hf) begin
					symbol <= rd_data;
				end
			end else begin
				if (x == (H_TOTAL-3)) begin
					// set the next address 
					if (y >= (V_TOTAL-1)) begin
						rd_addr <= 0;
					end else begin
						if (y[3:0] == 4'hf) begin
							rd_addr <= (lrg_row * LRG_COLS) + LRG_COLS;
						end else begin
							rd_addr <= (lrg_row * LRG_COLS);
						end
					end
				end else if (x == (H_TOTAL-1)) begin
					if (lrg_row >= LRG_ROWS) begin
						symbol <= 8'h00;
					end else begin
						symbol <= rd_data;
					end
				end
			end
		end
	end
endmodule
