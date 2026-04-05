`timescale 1ns/1ps
`default_nettype none
/*
	True-dual port N by 2048 deep 32-bit memory
	
This module uses four 18kbit memory blocks DP16KD to create N
dual ported 2048 entry deep 32-bit memories with distinct ports that can be
clocked independantly and can be used for read or writes each.

This module also supports native aligned 16 and 8 bit accesses with proper
steering of the data and write enables.

The module uses byte addressing so for instance the 16'th 32-bit word isn't 
at address 0x10 but instead address 0x40.

*/

module bram_dp_nx2048x32
#(
	parameter WRITEMODE_A="NORMAL", 		// "NORMAL", "WRITETHROUGH", "READBEFOREWRITE"
	parameter WRITEMODE_B="NORMAL",
	parameter REGMODE_A="NOREG",			// "NOREG", "REG"
	parameter REGMODE_B="NOREG",
	parameter N=2
)
(
    // Port A
    input wire    clk_a,			// clock
    input wire	  clk_en_a,			// clock enable
    input wire	  rst_a,			// active high reset
    input wire [12+$clog2(N):0] addr_a,		// 13+N-bit address
    input wire [31:0] din_a,		// 32-bit write input
    input wire [3:0] be_a,
    input wire    we_a,				// write enable
    output reg [31:0] dout_a,		// 32-bit read output

    // Port B
    input wire    clk_b,
    input wire	  clk_en_b,
    input wire    rst_b,
    input wire [12+$clog2(N):0] addr_b,
    input wire [31:0] din_b,
    input wire [3:0] be_b,
    input wire     we_b,
    output reg [31:0] dout_b
);

	genvar i;
	
	wire [31:0] mem_out_a[0:N-1];
	wire [31:0] mem_out_b[0:N-1];
	
	generate
		for (i = 0; i < N; i = i + 1) begin : bram_dp_n2048x32_memories
			bram_dp_2048x32 
				#(.WRITEMODE_A(WRITEMODE_A), .WRITEMODE_B(WRITEMODE_B), .REGMODE_A(REGMODE_A))
			bram_dp_nx2048x32_mem(
				.clk_a(clk_a),
				.clk_en_a(clk_en_a),
				.rst_a(rst_a),
				.addr_a(addr_a[12:0]),
				.be_a(be_a),
				.din_a(din_a),
				.we_a(we_a & ((addr_a[12+$clog2(N):13] == i) ? 1'b1 : 1'b0)),
				.dout_a(mem_out_a[i]),

				.clk_b(clk_b),
				.clk_en_b(clk_en_b),
				.rst_b(rst_b),
				.addr_b(addr_b[12:0]),
				.be_b(be_b),
				.din_b(din_b),
				.we_b(we_b & ((addr_b[12+$clog2(N):13] == i) ? 1'b1 : 1'b0)),
				.dout_b(mem_out_b[i])
			);
		end
	endgenerate
	
	always @(*) begin
		dout_a = mem_out_a[addr_a[12+$clog2(N):13]];
		dout_b = mem_out_b[addr_b[12+$clog2(N):13]];
	end		
endmodule
