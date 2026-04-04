`timescale 1ns/1ps
`default_nettype none
/*
	Semi-dual port N by 2048 deep 8-bit memory
	
This module uses 'N' 18kbit memory blocks DP16KD to create a
N by 2048 entry deep 8-bit memory with distinct read and write ports that
(because it's based on a DP memory) can be clocked independently.

*/

module bram_sp_nx2048x8 
#(
	parameter WRITEMODE_A="NORMAL", 	// "NORMAL", "WRITETHROUGH", "READBEFOREWRITE"
	parameter WRITEMODE_B="NORMAL",
	parameter REGMODE_A="NOREG",		// "NOREG", "REG"
	parameter N=2						// how many 2048x8 blocks to cascade into deeper 8-bit memory
)
(
    input w_clk,						// write clock
    input w_clk_en,						// write clock enable
    input w_rst,						// active high write reset
    input [10+$clog2(N):0] w_addr,		// write address 11+N-bits
    input [7:0] w_data,					// write data 8-bits
    input w_en,							// write enable

    input r_clk,						// read clock
    input r_clk_en,						// read clock enable
    input r_rst,						// active high read reset
    input [10+$clog2(N):0] r_addr,		// read address 11+N-bits
    output [7:0] r_data					// read data 8-bits
);
	genvar i;
	
	wire [7:0] mem_out[0:N-1];
	
	generate
		for (i = 0; i < N; i = i + 1) begin : bram_sp_n2048x8_memories
			bram_sp_2048x8 
				#(.WRITEMODE_A(WRITEMODE_A), .WRITEMODE_B(WRITEMODE_B), .REGMODE_A(REGMODE_A))
			bram_sp_nx2048x8_mem[i](
				.w_clk(w_clk),
				.w_clk_en(w_clk_en),
				.w_rst(w_rst),
				.w_addr(w_addr[10:0]),
				.w_data(w_data),
				.w_en(w_en & ((w_addr[10+$clog2(N):11] == i) ? 1'b1 : 1'b0)),

				.r_clk(r_clk),
				.r_clk_en(r_clk_en),
				.r_rst(r_rst),
				.r_addr(r_addr[10:0]),
				.r_data(mem_out[i])
			);
		end
	endgenerate
	
	always @(*) begin
		r_data = mem_out[r_addr[10+$clog2(N):11]];
	end		
endmodule
