// this outputs both the strobe stretch to 4 cycles (so 3MHz) and the rng bit
// stretching should be fine since it takes 65536 cycles to maybe produce 1 bit.
`default_nettype none
`timescale 1ns/1ps

module top(
	input wire clk,
	output reg rng_bit,
	output reg rng_strobe,
	output reg led
);
	reg rst_n;
	reg [3:0] strrrobe;
	
	initial begin
		rst_n = 0;
	end

	wire osc_bit;
	wire osc_strobe;
	
	osc_rng funnybits (.clk(clk), .rst_n(rst_n), .bit(osc_bit), .strobe(osc_strobe));
	
	always @(*) begin
		rng_strobe = strrrobe[3];
	end

	always @(posedge clk) begin
		rng_strobe <= osc_strobe;
		strrrobe   <= { strrrobe[2:0], 1'b0 };
		
		if (osc_strobe) begin
			strrrobe <= 4'b1111;
			rng_bit  <= osc_bit;
		end
		
		if (!rst_n) begin
			rst_n      <= 1'b1;
			rng_bit    <= 1'b0;
			strrrobe   <= 4'b0000;			
		end
	end
endmodule
