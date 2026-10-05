`include "nanofpu.vh"

`default_nettype none

/*

  This makes a 4:2:1 reduction tree where each of the 7 FPUs are configurable individually  The topology is as such:
  
  
  F00     F01     F02     F03
    \       /      \      /
     \     /        \    /
       F10           F11
          \         /
           \       /
            \     /
              F20


	Each Fxy is a nanofpu with their own ENABLED_FUNCS.  Every FPU is passed their own opcode.  Every FPU output and ready
	strobe are exposed.
	
	F0y: These are the input edge.  They each take 2 inputs and produce one output fed to the corresponding F1y FPU.
	F1y: These are the first inner layer, they only take inputs from corresponding F0y nodes.
	F2y: This is the final output stage.
	
	The F1y and F2y nodes all have enable bits so they can be selectively idled.  They only go valid (ready to start) when
	both inputs are ready and the enable bit is high.  This ensures that the bottom layers are ready for jobs.
	
	Because of the flexibility the top four FPUs can be used in a variety of configurations.  As part of a 4-space
	transform, or two 2-space transforms, or a 2-space and two scalar operations, or 4 scalars.  A 3-space calculation 
	can be emulated by making one node simply do a mult by 1.0 or add zero.

*/

module nanovex
#(
	parameter ENABLE_F00=(`NANOFPU_FL_FADD|`NANOFPU_FL_FMUL|`NANOFPU_FL_FSTI|`NANOFPU_FL_FLDI),
	parameter ENABLE_F01=(`NANOFPU_FL_FADD|`NANOFPU_FL_FMUL),
	parameter ENABLE_F02=(`NANOFPU_FL_FADD|`NANOFPU_FL_FMUL|`NANOFPU_FL_FSTI|`NANOFPU_FL_FLDI),
	parameter ENABLE_F03=(`NANOFPU_FL_FADD|`NANOFPU_FL_FMUL),
	parameter ENABLE_F10=`NANOFPU_FL_FADD,
	parameter ENABLE_F11=`NANOFPU_FL_FADD,
	parameter ENABLE_F20=`NANOFPU_FL_FADD,

	parameter HANDLE_INVALID_OP         = 1,   // 1 == signals when an invalid opcode hits (0 == locks up)
	parameter USE_FMUL_DSP     		    = 1,   // 0 == serial shifter, 1 == 36x36 DSP, 2 == 18x18 DSP, 3 == 2-bit serial multiplier
	parameter USE_FMUL_TWO_STAGE_CMP    = 1,   // 1 == pipeline the compares
	parameter USE_FDIV_BARREL           = 1,   // 0 == serial shifter, 1 == barrel shifter
	parameter USE_FDIV_TWO_STAGE_CMP    = 1,   // 1 == pipeline the compares
	parameter USE_FADDSUB_BARREL        = 1,   // Use barrel shifter for faddsub
	parameter USE_FADDSUB_TWO_STAGE_CMP = 1,   // Use pipelined comparison for sorting
	parameter USE_FADDSUB_BIG_STEP      = 1,   // Enable a 4-bit stride in the final norm, costs area
	parameter USE_FSTI_BARREL           = 1,   // Use barrel shifter for fsti (it's kinda big)
	parameter USE_FSQRT_STAGES          = 1,    // Use two stage (better fmax) FSQRT logic
	parameter USE_FPMUL16_DSP_MULT      = 0    // 0 == use 16x16 multipliers, 1 == use 32x32 multipliers										   
)
(
	input wire clk,
	input wire rst_n,
	
	input wire [127:0]     in_a,	// quad of 32-bits per F0y left hand side {F03, F02, F01, F00}
	input wire [127:0]     in_b,	// quad of 32-bits per F0y right hand side {F03, F02, F01, F00}
	input wire [7*4-1:0] opcode,	// sept of 4 bits ... 0=ADD, 1=SUB, 2=MUL, 3=DIV, 4=FLDI, 5=FSTI, 6=FSQRT, 7=FCMP, 8..11=IADD, 15=NOP
	input wire [3:0]      valid,	// command valid {F03, F02, F01, F00}
	output reg [7*32-1:0]   out,	// result data {f20, f11, f10, f03, f02, f01, f00}
	output reg [6:0]      ready,	// result strobe: output is ready {f20, f11, f10, f03, f02, f01, f00}
	output reg [6:0]      busy		// busy status of {f20, f11, f10, f03, f02, f01, f00}
);

	wire [6:0]      fpu_readies;
	wire [7*32-1:0] fpu_outs;
	
	// top layer FPUs
	nanofpu #( 
		.ENABLE_FUNCS(ENABLE_F00),
		.HANDLE_INVALID_OP(HANDLE_INVALID_OP),
		.USE_FMUL_DSP(USE_FMUL_DSP),
		.USE_FMUL_TWO_STAGE_CMP(USE_FMUL_TWO_STAGE_CMP),
		.USE_FDIV_BARREL(USE_FDIV_BARREL),
		.USE_FDIV_TWO_STAGE_CMP(USE_FDIV_TWO_STAGE_CMP),
		.USE_FADDSUB_BARREL(USE_FADDSUB_BARREL),
		.USE_FADDSUB_TWO_STAGE_CMP(USE_FADDSUB_TWO_STAGE_CMP),
		.USE_FADDSUB_BIG_STEP(USE_FADDSUB_BIG_STEP),
		.USE_FSTI_BARREL(USE_FSTI_BARREL),
		.USE_FPMUL16_DSP_MULT(USE_FPMUL16_DSP_MULT),
		.USE_FSQRT_STAGES(USE_FSQRT_STAGES)) nanofpu_f00
	(
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a[31:0]), .in_b(in_b[31:0]), .opcode(opcode[3:0]),
		.valid(valid[0]), .out(fpu_outs[31:0]), .ready(fpu_readies[0])
	);
		
	nanofpu #( 
		.ENABLE_FUNCS(ENABLE_F01),
		.HANDLE_INVALID_OP(HANDLE_INVALID_OP),
		.USE_FMUL_DSP(USE_FMUL_DSP),
		.USE_FMUL_TWO_STAGE_CMP(USE_FMUL_TWO_STAGE_CMP),
		.USE_FDIV_BARREL(USE_FDIV_BARREL),
		.USE_FDIV_TWO_STAGE_CMP(USE_FDIV_TWO_STAGE_CMP),
		.USE_FADDSUB_BARREL(USE_FADDSUB_BARREL),
		.USE_FADDSUB_TWO_STAGE_CMP(USE_FADDSUB_TWO_STAGE_CMP),
		.USE_FADDSUB_BIG_STEP(USE_FADDSUB_BIG_STEP),
		.USE_FSTI_BARREL(USE_FSTI_BARREL),
		.USE_FPMUL16_DSP_MULT(USE_FPMUL16_DSP_MULT),
		.USE_FSQRT_STAGES(USE_FSQRT_STAGES)) nanofpu_f01
	(
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a[63:32]), .in_b(in_b[63:32]), .opcode(opcode[7:4]),
		.valid(valid[1]), .out(fpu_outs[63:32]), .ready(fpu_readies[1])
	);

	nanofpu #( 
		.ENABLE_FUNCS(ENABLE_F02),
		.HANDLE_INVALID_OP(HANDLE_INVALID_OP),
		.USE_FMUL_DSP(USE_FMUL_DSP),
		.USE_FMUL_TWO_STAGE_CMP(USE_FMUL_TWO_STAGE_CMP),
		.USE_FDIV_BARREL(USE_FDIV_BARREL),
		.USE_FDIV_TWO_STAGE_CMP(USE_FDIV_TWO_STAGE_CMP),
		.USE_FADDSUB_BARREL(USE_FADDSUB_BARREL),
		.USE_FADDSUB_TWO_STAGE_CMP(USE_FADDSUB_TWO_STAGE_CMP),
		.USE_FADDSUB_BIG_STEP(USE_FADDSUB_BIG_STEP),
		.USE_FSTI_BARREL(USE_FSTI_BARREL),
		.USE_FPMUL16_DSP_MULT(USE_FPMUL16_DSP_MULT),
		.USE_FSQRT_STAGES(USE_FSQRT_STAGES)) nanofpu_f02
	(
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a[95:64]), .in_b(in_b[95:64]), .opcode(opcode[11:8]),
		.valid(valid[2]), .out(fpu_outs[95:64]), .ready(fpu_readies[2])
	);
		
	nanofpu #( 
		.ENABLE_FUNCS(ENABLE_F03),
		.HANDLE_INVALID_OP(HANDLE_INVALID_OP),
		.USE_FMUL_DSP(USE_FMUL_DSP),
		.USE_FMUL_TWO_STAGE_CMP(USE_FMUL_TWO_STAGE_CMP),
		.USE_FDIV_BARREL(USE_FDIV_BARREL),
		.USE_FDIV_TWO_STAGE_CMP(USE_FDIV_TWO_STAGE_CMP),
		.USE_FADDSUB_BARREL(USE_FADDSUB_BARREL),
		.USE_FADDSUB_TWO_STAGE_CMP(USE_FADDSUB_TWO_STAGE_CMP),
		.USE_FADDSUB_BIG_STEP(USE_FADDSUB_BIG_STEP),
		.USE_FSTI_BARREL(USE_FSTI_BARREL),
		.USE_FPMUL16_DSP_MULT(USE_FPMUL16_DSP_MULT),
		.USE_FSQRT_STAGES(USE_FSQRT_STAGES)) nanofpu_f03
	(
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a[127:96]), .in_b(in_b[127:96]), .opcode(opcode[15:12]),
		.valid(valid[3]), .out(fpu_outs[127:96]), .ready(fpu_readies[3])
	);
	
	reg [1:0] f10_deps;
	reg [1:0] f11_deps;
	reg [1:0] f20_deps;
	
	wire f10_valid;
	wire f11_valid;
	wire f20_valid;
	assign f10_valid = &f10_deps & ~busy[4];
	assign f11_valid = &f11_deps & ~busy[5];
	assign f20_valid = &f20_deps & ~busy[6];

	// F10 takes in F00 and F01 as inputs
	nanofpu #( 
		.ENABLE_FUNCS(ENABLE_F10),
		.HANDLE_INVALID_OP(HANDLE_INVALID_OP),
		.USE_FMUL_DSP(USE_FMUL_DSP),
		.USE_FMUL_TWO_STAGE_CMP(USE_FMUL_TWO_STAGE_CMP),
		.USE_FDIV_BARREL(USE_FDIV_BARREL),
		.USE_FDIV_TWO_STAGE_CMP(USE_FDIV_TWO_STAGE_CMP),
		.USE_FADDSUB_BARREL(USE_FADDSUB_BARREL),
		.USE_FADDSUB_TWO_STAGE_CMP(USE_FADDSUB_TWO_STAGE_CMP),
		.USE_FADDSUB_BIG_STEP(USE_FADDSUB_BIG_STEP),
		.USE_FSTI_BARREL(USE_FSTI_BARREL),
		.USE_FPMUL16_DSP_MULT(USE_FPMUL16_DSP_MULT),
		.USE_FSQRT_STAGES(USE_FSQRT_STAGES)) nanofpu_f10
	(
		.clk(clk), .rst_n(rst_n),
		.in_a(fpu_outs[31:0]), .in_b(fpu_outs[63:32]), .opcode(opcode[19:16]),
		.valid(f10_valid), .out(fpu_outs[159:128]), .ready(fpu_readies[4])
	);
	
	// F11 takes in F02 and F03 as inputs
	nanofpu #( 
		.ENABLE_FUNCS(ENABLE_F11),
		.HANDLE_INVALID_OP(HANDLE_INVALID_OP),
		.USE_FMUL_DSP(USE_FMUL_DSP),
		.USE_FMUL_TWO_STAGE_CMP(USE_FMUL_TWO_STAGE_CMP),
		.USE_FDIV_BARREL(USE_FDIV_BARREL),
		.USE_FDIV_TWO_STAGE_CMP(USE_FDIV_TWO_STAGE_CMP),
		.USE_FADDSUB_BARREL(USE_FADDSUB_BARREL),
		.USE_FADDSUB_TWO_STAGE_CMP(USE_FADDSUB_TWO_STAGE_CMP),
		.USE_FADDSUB_BIG_STEP(USE_FADDSUB_BIG_STEP),
		.USE_FSTI_BARREL(USE_FSTI_BARREL),
		.USE_FPMUL16_DSP_MULT(USE_FPMUL16_DSP_MULT),
		.USE_FSQRT_STAGES(USE_FSQRT_STAGES)) nanofpu_f11
	(
		.clk(clk), .rst_n(rst_n),
		.in_a(fpu_outs[95:64]), .in_b(fpu_outs[127:96]), .opcode(opcode[23:20]),
		.valid(f11_valid), .out(fpu_outs[191:160]), .ready(fpu_readies[5])
	);

	// F20 takes in F10 and F11 as inputs
	nanofpu #( 
		.ENABLE_FUNCS(ENABLE_F20),
		.HANDLE_INVALID_OP(HANDLE_INVALID_OP),
		.USE_FMUL_DSP(USE_FMUL_DSP),
		.USE_FMUL_TWO_STAGE_CMP(USE_FMUL_TWO_STAGE_CMP),
		.USE_FDIV_BARREL(USE_FDIV_BARREL),
		.USE_FDIV_TWO_STAGE_CMP(USE_FDIV_TWO_STAGE_CMP),
		.USE_FADDSUB_BARREL(USE_FADDSUB_BARREL),
		.USE_FADDSUB_TWO_STAGE_CMP(USE_FADDSUB_TWO_STAGE_CMP),
		.USE_FADDSUB_BIG_STEP(USE_FADDSUB_BIG_STEP),
		.USE_FSTI_BARREL(USE_FSTI_BARREL),
		.USE_FPMUL16_DSP_MULT(USE_FPMUL16_DSP_MULT),
		.USE_FSQRT_STAGES(USE_FSQRT_STAGES)) nanofpu_f20
	(
		.clk(clk), .rst_n(rst_n),
		.in_a(fpu_outs[159:128]), .in_b(fpu_outs[191:160]), .opcode(opcode[27:24]),
		.valid(f20_valid), .out(fpu_outs[223:192]), .ready(fpu_readies[6])
	);

	always @(posedge clk) begin
		// handle busy for F0x
		if (valid[0]) begin
			busy[0] <= 1;
		end
		if (valid[1]) begin
			busy[1] <= 1;
		end
		if (valid[2]) begin
			busy[2] <= 1;
		end
		if (valid[3]) begin
			busy[3] <= 1;
		end

		// handle inner layers by accumulating the readies into pairs in fxy_deps[1:0]
		// This allows the FPUs to finish on their own time and the next level only starts
		// when both are ready
		f10_deps <= f10_deps | {fpu_readies[0], fpu_readies[1]};
		f11_deps <= f11_deps | {fpu_readies[2], fpu_readies[3]};
		f20_deps <= f20_deps | {fpu_readies[4],	fpu_readies[5]};

		if (fpu_readies[0]) begin
			busy[0]      <= 0;
			out[31:0]    <= fpu_outs[31:0];
		end
		if (fpu_readies[1]) begin
			busy[1]      <= 0;
			out[63:32]   <= fpu_outs[63:32];
		end
		if (fpu_readies[2]) begin
			busy[2]      <= 0;
			out[95:64]   <= fpu_outs[95:64];
		end
		if (fpu_readies[3]) begin
			busy[3]      <= 0;
			out[127:96]  <= fpu_outs[127:96];
		end
		if (fpu_readies[4]) begin
			busy[4]      <= 0;
			out[159:128] <= fpu_outs[159:128];
		end
		if (fpu_readies[5]) begin
			busy[5]      <= 0;
			out[191:160] <= fpu_outs[191:160];
		end
		if (fpu_readies[6]) begin
			busy[6]      <= 0;
			out[223:192] <= fpu_outs[223:192];
		end

		// reset inners (fxy_valid is combinatorial so in the cycle where it goes high
		// we want to clear the deps so that valid goes low the next cycle)
		if (f10_valid) begin
			busy[4]  <= 1;
			f10_deps <= 0;
		end
		if (f11_valid) begin
			busy[5]  <= 1;
			f11_deps <= 0;
		end
		if (f20_valid) begin
			busy[6]  <= 1;
			f20_deps <= 0;
		end
		
		// readies
		ready <= fpu_readies;

		if (~rst_n) begin
			ready    <= 0;
			out      <= 0;
			f10_deps <= 0;
			f11_deps <= 0;
			f20_deps <= 0;
			busy     <= 0;
		end	
	end
endmodule

`include "nanofpu.v"
