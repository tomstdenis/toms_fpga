/* Text mode driver (flexible)

This renders a text display on a 640x400 viewport using 80/40 columns and 25/50 rows.

It assumes VGA timing by default.  

*/
`timescale 1ns/1ps
`default_nettype none

module texy_flexy #(
    parameter X_FETCH_DELAY = 1,                                    // when to fetch next symbol 1==comb, 2+ == sync
	parameter H_VISIBLE     = 640,  								// visible width		
	parameter V_VISIBLE     = 400,									// visible height
    parameter H_TOTAL       = 800,
    parameter V_TOTAL       = 525,
    parameter SYMBOL_BITS   = 8                                     // how many bits per text char
)
(
	input wire		                 clk,							// Pixel clock
	input wire		                 rst_n,							// active low reset

// VGA signalling
    input wire  [$clog2(V_TOTAL):0]  x,								// Pixel X coordinate
    input wire  [$clog2(H_TOTAL):0]  y,								// Pixel Y coordinate
    input wire                       x_dbl,							// 0 == 8 pixel wide font, 1 == 16 px wide
    input wire                       y_dbl,                         // 0 == 8 px tall font, 1 == 16 px tall

// Memory
	output reg [11:0]                rd_addr,		                // read address, assumes data is available with 1 wait state
	input wire [SYMBOL_BITS-1:0]     rd_data,						// read data
	
// symbol for font driver
	output reg [SYMBOL_BITS-1:0]     symbol							// symbol to feed font rom
);	
    reg [11:0] row_start;

	always @(posedge clk) begin
        // text mode
        if (y < V_VISIBLE && x < (H_VISIBLE - X_FETCH_DELAY)) begin
            // need to set next address
            // 8px:   every 8 - 2 * X_FETCH_DELAY
            // 16px:  every 16 - 2 * X_FETCH_DELAY
            if (~x_dbl && x[2:0] == (8-X_FETCH_DELAY-X_FETCH_DELAY)) begin // set address before next 8px 
                rd_addr <= rd_addr + 1'b1;
            end
            if (x_dbl && x[3:0] == (16-X_FETCH_DELAY-X_FETCH_DELAY)) begin // set address before next 16px 
                rd_addr <= rd_addr + 1'b1;
            end
            // Latch symbol at the last column of font
            // we do this X_FETCH_DELAY ahead of the next symbol
            if (~x_dbl && x[2:0] == (8-X_FETCH_DELAY)) begin
                symbol <= rd_data;
            end
            if (x_dbl && x[3:0] == (16-X_FETCH_DELAY)) begin
                symbol <= rd_data;
            end
        end else begin
            // we're either just entering HBLANK or VBLANK
            if (x < (H_TOTAL-2-X_FETCH_DELAY)) begin
                symbol <= 16'h0020;
            end else if (x == (H_TOTAL-2-X_FETCH_DELAY)) begin
                // set the next address for the next scanline which is either
                // another line of the same text char row or the first row of the next row of text...
                if (y >= (V_VISIBLE-1)) begin
                    rd_addr   <= 0;                                       // we're beyond the last row so start at 0
                    row_start <= 0;
                end else begin
                    if ((~y_dbl && y[2:0] == 7) ||
                        (y_dbl && y[3:0] == 15)) begin                    // next row of chars
                        row_start <= rd_addr;
                    end else begin
                        rd_addr   <= row_start;                           // restart th current row
                    end
                end
            end else if (x == (H_TOTAL-X_FETCH_DELAY)) begin
                if (y < (V_VISIBLE-1) || y == (V_TOTAL-1)) begin      // either we're in the first TEXTROWS OR the last line preparing for row 0
                    symbol <= rd_data;
                end else begin
                    symbol <= 16'h0020; // SPC
                end
            end
        end
        if (~rst_n) begin
            rd_addr   <= 0;
            row_start <= 0;
            symbol    <= 0;
        end
	end
endmodule
