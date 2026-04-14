`timescale 1ns/1ps
`default_nettype none
/*
	True-dual port N by 2048 deep 8-bit memory
	
This module uses 18kbit memory blocks DP16KD to create a
dual ported N by 2048 entry deep 8-bit memory with distinct ports that can be
clocked independently and can be used for read or writes each.

*/

module bram_dp_nx2048x8
#(
	parameter WRITEMODE_A="NORMAL", 		// "NORMAL", "WRITETHROUGH", "READBEFOREWRITE"
	parameter WRITEMODE_B="NORMAL",
	parameter REGMODE_A="NOREG",			// "NOREG", "REG"
	parameter REGMODE_B="NOREG",
	parameter N=2							// number of 2KiB blocks
)
(
    // Port A
    input wire    clk_a,			// clock
    input wire    clk_en_a,			// clock enable
    input wire    rst_a,			// active high reset
    input wire [10+$clog2(N):0] addr_a,	// 11-bit address
    input wire [7:0]  din_a,			// 8-bit write input wire
    input wire    we_a,				// write enable
    output wire [7:0]  dout_a,			// 8-bit read output

    // Port B
    input wire    clk_b,
    input wire    clk_en_b,
    input wire	  rst_b,
    input wire [10+$clog2(N):0] addr_b,
    input wire [7:0]  din_b,
    input wire    we_b,
    output wire [7:0]  dout_b
);

	genvar i;
	
	wire [7:0] mem_out_a[0:N-1];
	wire [7:0] mem_out_b[0:N-1];
	
	generate
		for (i = 0; i < N; i = i + 1) begin : bram_dp_n2048x8_memories
			bram_dp_2048x8 
				#(.WRITEMODE_A(WRITEMODE_A), .WRITEMODE_B(WRITEMODE_B), .REGMODE_A(REGMODE_A), .REGMODE_B(REGMODE_B))
			bram_dp_nx2048x8_mem[i](
				.clk_a(clk_a),
				.clk_en_a(clk_en_a),
				.rst_a(rst_a),
				.addr_a(addr_a[10:0]),
				.din_a(din_a),
				.we_a(we_a & ((addr_a[10+$clog2(N):11] == i[$clog2(N):0]) ? 1'b1 : 1'b0)),
				.dout_a(mem_out_a[i]),

				.clk_b(clk_b),
				.clk_en_b(clk_en_b),
				.rst_b(rst_b),
				.addr_b(addr_b[10:0]),
				.din_b(din_b),
				.we_b(we_b & ((addr_b[10+$clog2(N):11] == i[$clog2(N):0]) ? 1'b1 : 1'b0)),
				.dout_b(mem_out_b[i])
			);
		end
	endgenerate
	
	always @(*) begin
		dout_a = mem_out_a[addr_a[10+$clog2(N):11]];
		dout_b = mem_out_b[addr_b[10+$clog2(N):11]];
	end		
endmodule
