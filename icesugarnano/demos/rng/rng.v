`default_nettype none
`timescale 1ns/1ps

module top(
	input wire clk,
	output reg rng_bit,
	output reg rng_strobe,
	output reg led
);
	reg rst_n;
	
	initial begin
		rst_n = 0;
	end

	wire osc_bit;
	wire osc_strobe;
	
	osc_rng funnybits (.clk(clk), .rst_n(rst_n), .bit(osc_bit), .strobe(osc_strobe));

	always @(posedge clk) begin
		rng_strobe <= osc_strobe;
		
		if (osc_strobe) begin
			rng_bit <= osc_bit;
		end
		
		if (!rst_n) begin
			rst_n      <= 1'b1;
			rng_bit    <= 1'b0;
			rng_strobe <= 1'b0;
		end
	end
endmodule
