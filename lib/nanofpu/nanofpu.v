`default_nettype none
module nanofpu
#(
	parameter USE_MULT=0
)
(
	input wire clk,
	input wire rst_n,
	
	input wire [31:0] in_a,
	input wire [31:0] in_b,
	input wire [1:0]  opcode,		// 0=ADD, 1=SUB, 2=MUL, 3=DIV
	input wire        valid,		// command valid
	
	output reg [31:0] out,			// result
	output reg        ready			// result is valid
);

	wire fadd_ready;
	wire [31:0] fadd_out;

	faddsub faddsub(
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a), .in_b(in_b), .sub_op(opcode[0]), .valid((valid && opcode < 2) ? 1'b1 : 1'b0),
		.out(fadd_out), .ready(fadd_ready));

	wire fmul_ready;
	wire [31:0] fmul_out;
	fmul #(.USE_MULT(USE_MULT)) fmul (
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a), .in_b(in_b), .valid((valid && opcode == 2) ? 1'b1 : 1'b0),
		.out(fmul_out), .ready(fmul_ready));

	wire fdiv_ready;
	wire [31:0] fdiv_out;
	fdiv fdiv (
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a), .in_b(in_b), .valid((valid && opcode == 3) ? 1'b1 : 1'b0),
		.out(fdiv_out), .ready(fdiv_ready));

	always @(posedge clk) begin
		ready <= 1'b0;
		if (fadd_ready) begin
			out   <= fadd_out;
			ready <= 1'b1;
		end
		if (fmul_ready) begin
			out   <= fmul_out;
			ready <= 1'b1;
		end
		if (fdiv_ready) begin
			out   <= fdiv_out;
			ready <= 1'b1;
		end
		if (~rst_n) begin
			out   <= 32'b0;
			ready <= 1'b0;
		end
	end
endmodule

`include "faddsub.v"
`include "fmul.v"
`include "fdiv.v"
