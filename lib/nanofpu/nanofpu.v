`default_nettype none
module nanofpu
#(
	parameter ENABLE_FADDSUB = 1'b1,	// enable faddsub
	parameter ENABLE_FMUL    = 1'b1,	// enable fmul
	parameter ENABLE_FDIV    = 1'b1,	// enable fdiv
	parameter ENABLE_FLDI    = 1'b1,	// enable fldi
	parameter ENABLE_FSTI    = 1'b1,	// enable fsti

	parameter USE_MULT       = 0,		// Use inferred multiplier 
	parameter USE_BARREL     = 0,		// Use barrel shifter (for faddsub/etc)
)
(
	input wire clk,
	input wire rst_n,
	
	input wire [31:0] in_a,
	input wire [31:0] in_b,
	input wire [2:0]  opcode,		// 0=ADD, 1=SUB, 2=MUL, 3=DIV
	input wire        valid,		// command valid
	
	output reg [31:0] out,			// result
	output reg        ready			// result is valid
);

	wire fadd_ready;
	wire [31:0] fadd_out;

	faddsub #(.USE_BARREL(USE_BARREL)) faddsub(
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a), .in_b(in_b), .sub_op(opcode[0]), .valid((valid && opcode < 2) ? ENABLE_FADDSUB : 1'b0),
		.out(fadd_out), .ready(fadd_ready));

	wire fmul_ready;
	wire [31:0] fmul_out;
	fmul #(.USE_MULT(USE_MULT)) fmul (
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a), .in_b(in_b), .valid((valid && opcode == 2) ? ENABLE_FMUL : 1'b0),
		.out(fmul_out), .ready(fmul_ready));

	wire fdiv_ready;
	wire [31:0] fdiv_out;
	fdiv fdiv (
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a), .in_b(in_b), .valid((valid && opcode == 3) ? ENABLE_FDIV : 1'b0),
		.out(fdiv_out), .ready(fdiv_ready));

	wire fldi_ready;
	wire [31:0] fldi_out;
	fldi fldi (
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a), .valid((valid && opcode == 4) ? ENABLE_FLDI : 1'b0),
		.out(fldi_out), .ready(fldi_ready));

	wire fsti_ready;
	wire [31:0] fsti_out;
	fsti fsti (
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a), .valid((valid && opcode == 5) ? ENABLE_FSTI : 1'b0),
		.out(fsti_out), .ready(fsti_ready));


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
		if (fldi_ready) begin
			out   <= fldi_out;
			ready <= 1'b1;
		end
		if (fsti_ready) begin
			out   <= fsti_out;
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
`include "fldi.v"
`include "fsti.v"
