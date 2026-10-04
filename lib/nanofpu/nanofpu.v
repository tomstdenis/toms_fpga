/* Tom's One of a Kind almost FPU ...
*/
`include "nanofpu.vh"
`default_nettype none

module nanofpu
#(
	parameter ENABLE_FUNCS   = `NANOFPU_FUNCS_ALL,   // enable all functions
	parameter ENABLE_FADDSUB = ENABLE_FUNCS[`NANOFPU_OP_FADD],	// enable faddsub
	parameter ENABLE_FMUL    = ENABLE_FUNCS[`NANOFPU_OP_FMUL],	// enable fmul
	parameter ENABLE_FDIV    = ENABLE_FUNCS[`NANOFPU_OP_FDIV],	// enable fdiv
	parameter ENABLE_FLDI    = ENABLE_FUNCS[`NANOFPU_OP_FLDI],	// enable fldi
	parameter ENABLE_FSTI    = ENABLE_FUNCS[`NANOFPU_OP_FSTI],	// enable fsti
	parameter ENABLE_FSQRT   = ENABLE_FUNCS[`NANOFPU_OP_FSQRT], // enable fsqrt
	parameter ENABLE_FCMP    = ENABLE_FUNCS[`NANOFPU_OP_FCMP],  // enable fcmp
	parameter ENABLE_IADD    = ENABLE_FUNCS[`NANOFPU_OP_IADD],  // enable iaddsub

	parameter USE_FMUL_DSP     		    = 2,   // 0 == serial shifter, 1 == 36x36 DSP, 2 == 18x18 DSP, 3 == 2-bit serial shifter
	parameter USE_FMUL_TWO_STAGE_CMP    = 1,   // 1 == pipeline the compares
	parameter USE_FDIV_BARREL           = 1,   // 0 == serial shifter, 1 == barrel shifter
	parameter USE_FDIV_TWO_STAGE_CMP    = 1,   // 1 == pipeline the compares
	parameter USE_FADDSUB_BARREL        = 1,   // Use barrel shifter for faddsub
	parameter USE_FADDSUB_TWO_STAGE_CMP = 1,   // Use pipelined comparison for sorting
	parameter USE_FSTI_BARREL           = 1,   // Use barrel shifter for fsti (it's kinda big)
	parameter USE_FLDI_BIG_STEP         = 1,   // use big step hunt in FLDI to reduce max time
	parameter USE_FSQRT_STAGES 		    = 2	   // 0 == 24 cycle SQRT, 1 == 48 cycles, 2 == 72 cycles (all + overhead)
)
(
	input wire clk,
	input wire rst_n,
	
	input wire [31:0] in_a,
	input wire [31:0] in_b,
	input wire [3:0]  opcode,		// 0=ADD, 1=SUB, 2=MUL, 3=DIV, 4=FLDI, 5=FSTI, 6=FSQRT, 7=FCMP, 8=IADD
	input wire        valid,		// command valid
	
	output reg [31:0] out,			// result
	output reg        ready			// result is valid
);

	wire fadd_ready;
	wire [31:0] fadd_out;

	faddsub #(
		.USE_BARREL(USE_FADDSUB_BARREL),
		.USE_TWO_STAGE_CMP(USE_FADDSUB_TWO_STAGE_CMP)
	) faddsub(
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a), .in_b(in_b), 
		.sub_op(opcode[0]), // 0 == fadd, 1 == fsub
		.valid((valid && opcode < `NANOFPU_OP_FMUL) ? ENABLE_FADDSUB : 1'b0),
		.out(fadd_out), .ready(fadd_ready));

	wire fmul_ready;
	wire [31:0] fmul_out;
	fmul #(
		.USE_MULT(USE_FMUL_DSP),
		.USE_TWO_STAGE_CMP(USE_FMUL_TWO_STAGE_CMP)
	) fmul (
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a), .in_b(in_b), .valid((valid && opcode == `NANOFPU_OP_FMUL) ? ENABLE_FMUL : 1'b0),
		.out(fmul_out), .ready(fmul_ready));

	wire fdiv_ready;
	wire [31:0] fdiv_out;
	fdiv #(
		.USE_BARREL(USE_FDIV_BARREL),
		.USE_TWO_STAGE_CMP(USE_FDIV_TWO_STAGE_CMP)
	) fdiv (
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a), .in_b(in_b), .valid((valid && opcode == `NANOFPU_OP_FDIV) ? ENABLE_FDIV : 1'b0),
		.out(fdiv_out), .ready(fdiv_ready));

	wire fldi_ready;
	wire [31:0] fldi_out;
	fldi #(.USE_BIG_SHIFT(USE_FLDI_BIG_STEP)) fldi (
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a), .valid((valid && opcode == `NANOFPU_OP_FLDI) ? ENABLE_FLDI : 1'b0),
		.out(fldi_out), .ready(fldi_ready));

	wire fsti_ready;
	wire [31:0] fsti_out;
	fsti #(.USE_BARREL(USE_FSTI_BARREL)) fsti (
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a), .valid((valid && opcode == `NANOFPU_OP_FSTI) ? ENABLE_FSTI : 1'b0),
		.out(fsti_out), .ready(fsti_ready));

	wire fsqrt_ready;
	wire [31:0] fsqrt_out;
	fsqrt #(.STAGES(USE_FSQRT_STAGES)) fsqrt (
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a), .valid((valid && opcode == `NANOFPU_OP_FSQRT) ? ENABLE_FSQRT : 1'b0),
		.out(fsqrt_out), .ready(fsqrt_ready));

	wire fcmp_ready;
	wire [31:0] fcmp_out;
	fcmp fcmp (
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a), .in_b(in_b), .valid((valid && opcode == `NANOFPU_OP_FCMP) ? ENABLE_FCMP : 1'b0),
		.out(fcmp_out), .ready(fcmp_ready));

	wire iaddsub_ready;
	wire [31:0] iaddsub_out;
	wire [1:0] iaddsub_op;
	assign iaddsub_op = opcode - `NANOFPU_OP_IADD;
	iaddsub iaddsub (
		.clk(clk), .rst_n(rst_n), .sub_op(iaddsub_op),
		.in_a(in_a), .in_b(in_b), .valid((valid && opcode >= `NANOFPU_OP_IADD && opcode <= (`NANOFPU_OP_IADD + 3)) ? ENABLE_IADD : 1'b0),
		.out(iaddsub_out), .ready(iaddsub_ready));

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
		if (fsqrt_ready) begin
			out   <= fsqrt_out;
			ready <= 1'b1;
		end
		if (fcmp_ready) begin
			out   <= fcmp_out;
			ready <= 1'b1;
		end
		if (iaddsub_ready) begin
			out   <= iaddsub_out;
			ready <= 1'b1;
		end
		if (valid && opcode == `NANOFPU_OP_NOP) begin
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
`include "fsqrt.v"
`include "fcmp.v"
`include "intaddsub.v"
