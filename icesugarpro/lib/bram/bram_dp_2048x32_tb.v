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

module bram_dp_2048x32_tb();

	reg clk;
	reg rst;
	
	wire clk_a = clk;
	wire clk_en_a = 1'b1;
	wire rst_a = rst;
	reg [12:0] addr_a;
	reg [31:0] din_a;
	reg [3:0] be_a;
	reg we_a;
	wire [31:0] dout_a;
	
	wire clk_b = clk;
	wire clk_en_b = 1'b1;
	wire rst_b = rst;
	reg [12:0] addr_b;
	reg [31:0] din_b;
	reg [3:0] be_b;
	reg we_b;
	wire [31:0] dout_b;

	bram_dp_2048x32 #(
		.WRITEMODE_A("NORMAL"),
		.WRITEMODE_B("NORMAL"),
		.REGMODE_A("NOREG"),
		.REGMODE_B("NOREG"))
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
    integer testphase;
    reg writeport;
    reg readport;

	initial begin
        // Waveform setup
        $dumpfile("bram_dp_2048x32.vcd");
        $dumpvars(0, bram_dp_2048x32_tb);
        
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
        
        
        // simple 32-bit write/read
        testphase = 0;
        write_mem(32'h12345678, 13'h1234, 4'b1111, writeport);
        write_mem(32'h11223344, 13'h1238, 4'b1111, writeport);
        read_mem(32'h12345678, 13'h1234, 4'b1111, readport);
        read_mem(32'h11223344, 13'h1238, 4'b1111, readport);
        
        // simple 16 bit reads and then writes
        testphase = 1;
        read_mem(32'h00005678, 13'h1234, 4'b0011, readport);
        read_mem(32'h00001234, 13'h1236, 4'b0011, readport);
        write_mem(32'h0000AABB, 13'h123A, 4'b0011, writeport);
        write_mem(32'h0000CCDD, 13'h123C, 4'b0011, writeport);
		read_mem(32'h0000AABB, 13'h123A, 4'b0011, readport);
        read_mem(32'h0000CCDD, 13'h123C, 4'b0011, readport);
        
        
        // simple 8-bit reads and then writes
        testphase = 2;
        read_mem(32'h00000078, 13'h1234, 4'b0001, readport);
        read_mem(32'h00000056, 13'h1235, 4'b0001, readport);
        read_mem(32'h00000034, 13'h1236, 4'b0001, readport);
        read_mem(32'h00000012, 13'h1237, 4'b0001, readport);
        write_mem(32'h000000AB, 13'h1240, 4'b0001, writeport);
        write_mem(32'h000000CD, 13'h1241, 4'b0001, writeport);
        write_mem(32'h000000EF, 13'h1242, 4'b0001, writeport);
        write_mem(32'h00000098, 13'h1243, 4'b0001, writeport);
        read_mem(32'h98EFCDAB, 13'h1240, 4'b1111, readport);
        
		repeat(16) @(posedge clk);
		$finish;
	end
	
	task write_mem(input [31:0] din, input [12:0] addr, input [3:0] be, input port);
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
	task read_mem(input [31:0] expected, input [12:0] addr, input [3:0] be, input port);
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

