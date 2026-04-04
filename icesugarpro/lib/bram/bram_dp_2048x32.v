`timescale 1ns/1ps
`default_nettype none
/*
	True-dual port 2048 deep 32-bit memory
	
This module uses four 18kbit memory blocks DP16KD to create a
dual ported 2048 entry deep 32-bit memory with distinct ports that can be
clocked independantly and can be used for read or writes each.

This module also supports native aligned 16 and 8 bit accesses with proper
steering of the data and write enables.

The module uses byte addressing so for instance the 16'th 32-bit word isn't 
at address 0x10 but instead address 0x40.

*/

module bram_dp_2048x32
#(
	parameter WRITEMODE_A="NORMAL", 		// "NORMAL", "WRITETHROUGH", "READBEFOREWRITE"
	parameter WRITEMODE_B="NORMAL",
	parameter REGMODE_A="NOREG",			// "NOREG", "REG"
	parameter REGMODE_B="NOREG"
)
(
    // Port A
    input wire    clk_a,			// clock
    input wire	  clk_en_a,			// clock enable
    input wire	  rst_a,			// active high reset
    input wire [12:0] addr_a,		// 13-bit address
    input wire [31:0] din_a,		// 32-bit write input
    input wire [3:0] be_a,
    input wire    we_a,				// write enable
    output wire [31:0] dout_a,		// 32-bit read output

    // Port B
    input wire    clk_b,
    input wire	  clk_en_b,
    input wire    rst_b,
    input wire [12:0] addr_b,
    input wire [31:0] din_b,
    input wire [3:0] be_b,
    input wire     we_b,
    output wire [31:0] dout_b
);
	
	// PORT A
    wire [31:0] o_mem_a;
    wire [1:0]  byte_offset_a = addr_a[1:0];

    // --- Input Steering (Write Data) ---
    // Using a more compact shift-based approach
    wire [31:0] i_mem_a = (be_a == 4'b1111) ? din_a : 
							(be_a == 4'b0011) ? (byte_offset_a[1] ? {din_a[15:0], 16'b0} : {16'b0, din_a[15:0]}) :
								(din_a[7:0] << (8 * byte_offset_a));

    // --- Write Enable Mapping ---
    wire [3:0] be_shifted_a = (be_a == 4'b1111) ? 4'b1111 :
								(be_a == 4'b0011) ? (byte_offset_a[1] ? 4'b1100 : 4'b0011) :
									(4'b0001 << byte_offset_a);
    
    wire [3:0] wren_a = we_a ? be_shifted_a : 4'b0000;

    // --- Output Steering (Read Data) ---
    // Note: pipe_byte_offset aligns this mux with the 1-cycle BRAM latency
    assign dout_a  = (be_a == 4'b1111) ? o_mem_a :
							(be_a == 4'b0011) ? (byte_offset_a[1] ? o_mem_a[31:16] : o_mem_a[15:0]) :
                                       ((o_mem_a >> (8 * byte_offset_a)) & 8'hFF);


	// PORT B
    wire [31:0] o_mem_b;
    wire [1:0]  byte_offset_b = addr_b[1:0];

    // --- Input Steering (Write Data) ---
    // Using a more compact shift-based approach
    wire [31:0] i_mem_b = (be_b == 4'b1111) ? din_b : 
							(be_b == 4'b0011) ? (byte_offset_b[1] ? {din_b[15:0], 16'b0} : {16'b0, din_b[15:0]}) :
								(din_b[7:0] << (8 * byte_offset_b));

    // --- Write Enable Mapping ---
    wire [3:0] be_shifted_b = (be_b == 4'b1111) ? 4'b1111 :
								(be_b == 4'b0011) ? (byte_offset_b[1] ? 4'b1100 : 4'b0011) :
									(4'b0001 << byte_offset_b);
    
    wire [3:0] wren_b = we_b ? be_shifted_b : 4'b0000;

    // --- Output Steering (Read Data) ---
    // Note: pipe_byte_offset aligns this mux with the 1-cycle BRAM latency
    assign dout_b  = (be_b == 4'b1111) ? o_mem_b :
							(be_b == 4'b0011) ? (byte_offset_b[1] ? o_mem_b[31:16] : o_mem_b[15:0]) :
                                       ((o_mem_b >> (8 * byte_offset_b)) & 8'hFF);

    genvar k;
    generate
        for (k = 0; k < 4; k = k+1) begin : bram_dp_2048_x32_lanes
			bram_dp_2048x8 #(
				.WRITEMODE_A(WRITEMODE_A),
				.WRITEMODE_B(WRITEMODE_B),
				.REGMODE_A(REGMODE_A),
				.REGMODE_B(REGMODE_B)
			) bram_dp_2048_x32_bram[k] (
				.clk_a(clk_a),
				.clk_en_a(clk_en_a),
				.rst_a(rst_a),
				.addr_a(addr_a[12:2]),
				.din_a(i_mem_a[k*8 +: 8]),
				.we_a(wren_a[k]),
				.dout_a(o_mem_a[k*8 +: 8]),

				.clk_b(clk_b),
				.clk_en_b(clk_en_b),
				.rst_b(rst_b),
				.addr_b(addr_b[12:2]),
				.din_b(i_mem_b[k*8 +: 8]),
				.we_b(wren_b[k]),
				.dout_b(o_mem_b[k*8 +: 8])
			);
		end
    endgenerate
endmodule
