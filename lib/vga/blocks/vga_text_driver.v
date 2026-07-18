/* Text mode driver

The purpose of this module is given a 2KB BRAM memory it produces
one output 'symbol' in step with the VGA signalling so the font
rom can produce the signal to output

*/
`timescale 1ns/1ps
`default_nettype none

module vga_text_driver #(
    parameter X_FETCH_DELAY = 1,                                    // when to fetch next symbol 1==comb, 2+ == sync
	parameter H_VISIBLE  = 640,										// visible width		
	parameter V_VISIBLE  = 480,										// visible height
    parameter V_TOTAL    = 525,
    parameter H_TOTAL    = 800,
	parameter TEXTCOLS   = 80,										// number of text columns
	parameter TEXTROWS   = 25,										// number of text rows
	parameter FONTWIDTH  = 8,										// font width in pixels
	parameter FONTHEIGHT = 8,										// font height in pixels
	parameter LRG_COLS   = 48,
	parameter LRG_ROWS   = 40,
	parameter LRG_PWIDTH = 13,										// width of "pixels" in LRG mode
	parameter LRG_PHEIGHT = 12										// height of "pixels" in LRG mode
)
(
	input wire		   clk,											// Pixel clock
	input wire		   rst_n,										// active low reset

// VGA signalling
    input wire  [$clog2(V_TOTAL):0]  x,								// Pixel X coordinate
    input wire  [$clog2(H_TOTAL):0]  y,								// Pixel Y coordinate
    input wire        active_video,									// is the video active (not in blanking region)
    input wire        lrg_mode,										// 0 == text mode, 1 == low res graphics mode

// Memory
	output reg [$clog2(LRG_COLS*LRG_ROWS | TEXTCOLS*TEXTROWS)-1:0] rd_addr,				// read address, assumes data is available with 1 wait state
	input wire [7:0] rd_data,										// read data
	
// symbol for font driver
	output reg [7:0] symbol											// symbol to feed font rom
);	

	// Combinatorial address calculation is much safer
	reg [3:0] x_cnt;
	reg [3:0] y_cnt;

	always @(posedge clk) begin
		if (!rst_n) begin
			rd_addr <= 0;
            symbol  <= 0;
			x_cnt   <= 0;
			y_cnt   <= 0;
		end else if (lrg_mode == 0) begin
			// text mode
			if (y < (TEXTROWS*FONTHEIGHT) && x < (TEXTCOLS*FONTWIDTH)) begin
                if (x_cnt >= (FONTWIDTH-1)) begin
                    x_cnt    <= 0;
                end else begin
                    x_cnt    <= x_cnt + 1;
                end
				if (x[$clog2(FONTWIDTH)-1:0] == (FONTWIDTH-2-X_FETCH_DELAY)) begin
					rd_addr <= rd_addr + 1;
				end
				// Latch symbol at the last column of font
				if (x[$clog2(FONTWIDTH)-1:0] == (FONTWIDTH-X_FETCH_DELAY)) begin
					symbol <= rd_data;
				end
			end else begin
                // we're either just entering HBLANK or VBLANK
				if (x == (H_TOTAL-3-X_FETCH_DELAY)) begin
					// set the next address for the next scanline which is either
                    // another line of the same text char row or the first row of the next row of text...
					if (y >= (TEXTROWS*FONTHEIGHT-1)) begin
						rd_addr <= 0;                                               // we're beyond the last row so start at 0
					end else begin
						if (y[$clog2(FONTHEIGHT)-1:0] == (FONTHEIGHT-1)) begin      // next row of chars
							rd_addr <= rd_addr;
						end else begin
							rd_addr <= rd_addr - TEXTCOLS;                          // next font row of same text row
						end
					end
				end else if (x == (H_TOTAL-1-X_FETCH_DELAY)) begin
                    x_cnt    <= 0;
                    if (y_cnt >= (FONTHEIGHT-1)) begin
                        y_cnt    <= 0;
                    end else begin
                        y_cnt    <= y_cnt + 1;
                    end
                    if (y == (V_TOTAL-1)) begin
                        y_cnt    <= 0;
                    end
                    if (y < (TEXTROWS*FONTHEIGHT-1)|| y == (V_TOTAL-1)) begin      // either we're in the first TEXTROWS OR the last line preparing for row 0
                        symbol <= rd_data;
                    end else begin
                        symbol <= 8'h20; // SPC
                    end
				end
			end
		end else begin
			if (x_cnt >= (LRG_PWIDTH-1)) begin
				x_cnt   <= 0;
			end else begin
				x_cnt   <= x_cnt + 1'b1;
			end
			// lowres graphics mode
			if (x < (LRG_COLS * LRG_PWIDTH) && y < (LRG_ROWS * LRG_PHEIGHT)) begin
                if (x_cnt == (LRG_PWIDTH-3)) begin
                    rd_addr <= rd_addr + 1;
                end
				if (x_cnt == (LRG_PWIDTH-1)) begin
                    if ((x > (LRG_PWIDTH*(LRG_COLS-1))) && (x < (LRG_PWIDTH*(LRG_COLS)))) begin
                        symbol <= 0;
                    end else begin
                        symbol  <= rd_data;
                    end
				end
			end else begin
				symbol  <= 8'h00;
				x_cnt   <= 0;
				if (x == (H_TOTAL-3)) begin
					// set the next address a little back from end so we can program the address to read from
					if (y >= (V_TOTAL-1)) begin
						// last row so we're starting over
						rd_addr <= 0;
					end else begin
						if (y_cnt == (LRG_PHEIGHT-1)) begin
							// last vga row of this lrg pixel
							rd_addr <= rd_addr;
						end else begin
							rd_addr <= rd_addr - LRG_COLS;
						end
					end
				end else if (x == (H_TOTAL-1)) begin
					symbol <= rd_data;
					// last column 
					if (y == (V_TOTAL-1)) begin
						y_cnt   <= 0;
					end else begin
						if (y_cnt >= (LRG_PHEIGHT-1)) begin
							y_cnt <= 0;
						end else begin
							y_cnt <= y_cnt + 1'b1;
						end
					end
				end
			end
		end
	end
endmodule
