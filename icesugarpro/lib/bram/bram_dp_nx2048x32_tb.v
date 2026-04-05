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

module bram_dp_nx2048x32_tb();

	reg clk;
	reg rst;
	
	wire clk_a = clk;
	wire clk_en_a = 1'b1;
	wire rst_a = rst;
	reg [14:0] addr_a;
	reg [31:0] din_a;
	reg [3:0] be_a;
	reg we_a;
	wire [31:0] dout_a;
	
	wire clk_b = clk;
	wire clk_en_b = 1'b1;
	wire rst_b = rst;
	reg [14:0] addr_b;
	reg [31:0] din_b;
	reg [3:0] be_b;
	reg we_b;
	wire [31:0] dout_b;

	bram_dp_nx2048x32 #(
		.WRITEMODE_A("NORMAL"),
		.WRITEMODE_B("NORMAL"),
		.REGMODE_A("NOREG"),
		.REGMODE_B("NOREG"),
		.N(4))
	bram_dut (
		.clk_a(clk_a),
		.clk_en_a(clk_en_a),
		.rst_a(rst_a),
		.addr_a(addr_a),
		.din_a(din_a),
		.be_a(be_a),
		.we_a(we_a),
		.dout_a(dout_a),
		
 		.clk_b(clk_b),
		.clk_en_b(clk_en_b),
		.rst_b(rst_b),
		.addr_b(addr_b),
		.din_b(din_b),
		.be_b(be_b),
		.we_b(we_b),
		.dout_b(dout_b));

    // Parameters for the simulation
    localparam CLK_PERIOD = 20; // 50MHz Clock
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;
    
    integer i;
    integer j;
    integer k;
    integer testphase;
    reg writeport;
    reg readport;
    reg [14:0] testoff;

	initial begin
        // Waveform setup
        $dumpfile("bram_dp_nx2048x32.vcd");
        $dumpvars(0, bram_dp_nx2048x32_tb);
        
        writeport = 0;
        readport = 0;
        clk = 0;
        rst = 1; // active high reset
        addr_a = 0;
        din_a = 0;
        we_a = 0;
        be_a = 0;
        addr_b = 0;
        din_b = 0;
        we_b = 0;
        be_b = 0;
        
        repeat(3) @(posedge clk);
        #1; rst = 0;
        @(posedge clk); #1
        
        for (i = 0; i < 4; i = i + 1) begin
			writeport = i[0];
			readport = i[1];
			testoff = i[14:0];
			testoff = 15'h2100 * testoff;
				
			// simple 32-bit write/read
			testphase = 0;
			write_mem(32'h12345678, 15'h1234 + testoff, 4'b1111, writeport);
			write_mem(32'h11223344, 15'h1238 + testoff, 4'b1111, writeport);
			read_mem(32'h12345678, 15'h1234 + testoff, 4'b1111, readport);
			read_mem(32'h11223344, 15'h1238 + testoff, 4'b1111, readport);
			
			// simple 16 bit reads and then writes
			testphase = 1;
			read_mem(32'h00005678, 15'h1234 + testoff, 4'b0011, readport);
			read_mem(32'h00001234, 15'h1236 + testoff, 4'b0011, readport);
			write_mem(32'h0000AABB, 15'h123A + testoff, 4'b0011, writeport);
			write_mem(32'h0000CCDD, 15'h123C + testoff, 4'b0011, writeport);
			read_mem(32'h0000AABB, 15'h123A + testoff, 4'b0011, readport);
			read_mem(32'h0000CCDD, 15'h123C + testoff, 4'b0011, readport);
			
			
			// simple 8-bit reads and then writes
			testphase = 2;
			read_mem(32'h00000078, 15'h1234 + testoff, 4'b0001, readport);
			read_mem(32'h00000056, 15'h1235 + testoff, 4'b0001, readport);
			read_mem(32'h00000034, 15'h1236 + testoff, 4'b0001, readport);
			read_mem(32'h00000012, 15'h1237 + testoff, 4'b0001, readport);
			write_mem(32'h000000AB, 15'h1240 + testoff, 4'b0001, writeport);
			write_mem(32'h000000CD, 15'h1241 + testoff, 4'b0001, writeport);
			write_mem(32'h000000EF, 15'h1242 + testoff, 4'b0001, writeport);
			write_mem(32'h00000098, 15'h1243 + testoff, 4'b0001, writeport);
			read_mem(32'h98EFCDAB, 15'h1240 + testoff, 4'b1111, readport);

			// write full blocks
			testphase = 3;
			for (j = 0; j < 4; j = j + 1) begin
				testphase = 3 + j;
				for (k = 0; k < 2048; k = k + 1) begin
					testoff = k[14:0] + 15'h2000 * j[14:0];
					write_mem(32'h00000011 * (j[31:0] + 32'd1), testoff, 4'b0001, writeport);
				end
			end

			// read full blocks
			for (j = 0; j < 4; j = j + 1) begin
				for (k = 0; k < 2048; k = k + 1) begin
					testoff = k[14:0] + 15'h2000 * j[14:0];
					read_mem(32'h00000011 * (j[31:0] + 32'd1), testoff, 4'b0001, readport);
				end
			end
		end
		
		repeat(16) @(posedge clk);
		$finish;
	end
	
	task write_mem(input [31:0] din, input [14:0] addr, input [3:0] be, input port);
		begin
			if (port == 0) begin
				// use port A
				addr_a = addr;
				din_a = din;
				be_a = be;
				we_a = 1;
				@(posedge clk); #1;
				we_a = 0;
				@(posedge clk); #1;
			end else begin
				// use port B;
				addr_b = addr;
				din_b = din;
				be_b = be;
				we_b = 1;
				@(posedge clk); #1;
				we_b = 0;
				@(posedge clk); #1;
			end
		end
	endtask	
	task read_mem(input [31:0] expected, input [14:0] addr, input [3:0] be, input port);
		begin
			if (port == 0) begin
				// use port A
				addr_a = addr;
				be_a = be;
				@(posedge clk); #1;
				@(posedge clk); #1;
				if (dout_a !== expected) begin
					$display("Expected read from port %d at address %h, be %b, failed %h vs %h", port, addr, be, dout_a, expected);
					$fatal;
				end
			end else begin
				// use port B;
				addr_b = addr;
				be_b = be;
				@(posedge clk); #1;
				@(posedge clk); #1;
				if (dout_b !== expected) begin
					$display("Expected read from port %d at address %h, be %b, failed %h vs %h", port, addr, be, dout_b, expected);
					$fatal;
				end
			end
		end
	endtask	

endmodule

