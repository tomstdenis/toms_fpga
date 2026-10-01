/*
	Saturating parallel 8/16 bit add/subtraction
	
	ICE40: 255 LUT4, 33 DFF, 128 CARRY
	ECP5:  141 LUT4, 33 DFF, 70 CARRY, 4 L6MUX21, 22 PFUMX

*/
`default_nettype none

module iaddsub
(
	input wire clk,
	input wire rst_n,
	
	input wire [31:0] in_a,
	input wire [31:0] in_b,
	input wire [1:0]  sub_op,		// 0 == satadd8, 1 == satsub8, 2 == satadd16, 3 == satsub16
	input wire        valid,		// command valid
	
	output reg [31:0] out,			// result
	output reg        ready			// result is valid
);

	always @(posedge clk) begin
		ready     <= 1'b0;
		if (~ready & valid) begin
			ready <= 1'b1;
			case (sub_op)
				2'b00: begin // satadd8
					if ((in_a[7:0] + in_b[7:0]) > 9'd255) begin
						out[7:0] <= 255;
					end else begin
						out[7:0] <= in_a[7:0] + in_b[7:0];
					end
					if ((in_a[15:8] + in_b[15:8]) > 9'd255) begin
						out[15:8] <= 255;
					end else begin
						out[15:8] <= in_a[15:8] + in_b[15:8];
					end
					if ((in_a[23:16] + in_b[23:16]) > 9'd255) begin
						out[23:16] <= 255;
					end else begin
						out[23:16] <= in_a[23:16] + in_b[23:16];
					end
					if ((in_a[31:24] + in_b[31:24]) > 9'd255) begin
						out[31:24] <= 255;
					end else begin
						out[31:24] <= in_a[31:24] + in_b[31:24];
					end
				end
				2'b01: begin // satsub8
					if (in_a[7:0] < in_b[7:0]) begin
						out[7:0] <= 0;
					end else begin
						out[7:0] <= in_a[7:0] - in_b[7:0];
					end
					if (in_a[15:8] < in_b[15:8]) begin
						out[15:8] <= 0;
					end else begin
						out[15:8] <= in_a[15:8] - in_b[15:8];
					end
					if (in_a[23:16] < in_b[23:16]) begin
						out[23:16] <= 0;
					end else begin
						out[23:16] <= in_a[23:16] - in_b[23:16];
					end
					if (in_a[31:24] < in_b[31:24]) begin
						out[31:24] <= 0;
					end else begin
						out[31:24] <= in_a[31:24] - in_b[31:24];
					end
				end
				2'b10: begin // satadd16
					if ((in_a[15:0] + in_b[15:0]) > 17'd65535) begin
						out[15:0] <= 65535;
					end else begin
						out[15:0] <= in_a[15:0] + in_b[15:0];
					end
					if ((in_a[31:16] + in_b[31:16]) > 17'd65535) begin
						out[31:16] <= 65535;
					end else begin
						out[31:16] <= in_a[31:16] + in_b[31:16];
					end
				end
				2'b11: begin // satsub16
					if (in_a[15:0] < in_b[15:0]) begin
						out[15:0] <= 0;
					end else begin
						out[15:0] <= in_a[15:0] - in_b[15:0];
					end
					if (in_a[31:16] < in_b[31:16]) begin
						out[31:16] <= 0;
					end else begin
						out[31:16] <= in_a[31:16] - in_b[31:16];
					end
				end
			endcase				
		end
		if (~rst_n) begin
			out <= 0;
		end
	end
endmodule
