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
	parameter ENABLE_F00=`NANOFPU_FUNCS_ALL,
	parameter ENABLE_F01=`NANOFPU_FUNCS_ALL,
	parameter ENABLE_F02=`NANOFPU_FUNCS_ALL,
	parameter ENABLE_F03=`NANOFPU_FUNCS_ALL,
	parameter ENABLE_F10=`NANOFPU_FUNCS_ALL,
	parameter ENABLE_F11=`NANOFPU_FUNCS_ALL,
	parameter ENABLE_F20=`NANOFPU_FUNCS_ALL,

	parameter USE_FMUL_DSP     		 = 2,	// 0 -- serial shifter, 1 == 36x36 DSP, 2 == 18x18 DSP
	parameter USE_FADDSUB_BARREL     = 1,	// Use barrel shifter for faddsub
	parameter USE_FSTI_BARREL        = 1,	// Use barrel shifter for fsti (it's kinda big)
	parameter USE_FSQRT_TWO_STAGE    = 1
)
(
	input wire clk,
	input wire rst_n,
	
	input wire [127:0] in_a,		// quad of 32-bits per F0y
	input wire [127:0] in_b,		// quad of 32-bits per F0y
	input wire [7*3-1:0]  opcode,	// sept of 3 bits ... 0=ADD, 1=SUB, 2=MUL, 3=DIV, 4=FLDI, 5=FSTI, 6=FSQRT
	input wire [3:0]    valid,		// command valid
	output reg [7*32-1:0] out,		// result data {f20, f11, f10, f03, f02, f01, f00}
	output reg [6:0]    ready,		// result is ready {f20, f11, f10, f03, f02, f01, f00}
	
	input wire [2:0]    fpu_enables // enables for {f20, f11, f10}
);

	wire [6:0]      fpu_readies;
	wire [7*32-1:0] fpu_outs;
	
	// top layer FPUs
	nanofpu #( 
		.ENABLE_FUNCS(ENABLE_F00),
		.USE_FMUL_DSP(USE_FMUL_DSP),
		.USE_FADDSUB_BARREL(USE_FADDSUB_BARREL),
		.USE_FSTI_BARREL(USE_FSTI_BARREL),
		.USE_FSQRT_TWO_STAGE(USE_FSQRT_TWO_STAGE)) nanofpu_f00
	(
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a[31:0]), .in_b(in_b[31:0]), .opcode(opcode[2:0]),
		.valid(valid[0]), .out(fpu_outs[31:0]), .ready(fpu_readies[0])
	);
		
	nanofpu #( 
		.ENABLE_FUNCS(ENABLE_F01),
		.USE_FMUL_DSP(USE_FMUL_DSP),
		.USE_FADDSUB_BARREL(USE_FADDSUB_BARREL),
		.USE_FSTI_BARREL(USE_FSTI_BARREL),
		.USE_FSQRT_TWO_STAGE(USE_FSQRT_TWO_STAGE)) nanofpu_f01
	(
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a[63:32]), .in_b(in_b[63:32]), .opcode(opcode[5:3]),
		.valid(valid[1]), .out(fpu_outs[63:32]), .ready(fpu_readies[1])
	);

	nanofpu #( 
		.ENABLE_FUNCS(ENABLE_F02),
		.USE_FMUL_DSP(USE_FMUL_DSP),
		.USE_FADDSUB_BARREL(USE_FADDSUB_BARREL),
		.USE_FSTI_BARREL(USE_FSTI_BARREL),
		.USE_FSQRT_TWO_STAGE(USE_FSQRT_TWO_STAGE)) nanofpu_f02
	(
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a[95:64]), .in_b(in_b[95:64]), .opcode(opcode[8:6]),
		.valid(valid[2]), .out(fpu_outs[95:64]), .ready(fpu_readies[2])
	);
		
	nanofpu #( 
		.ENABLE_FUNCS(ENABLE_F03),
		.USE_FMUL_DSP(USE_FMUL_DSP),
		.USE_FADDSUB_BARREL(USE_FADDSUB_BARREL),
		.USE_FSTI_BARREL(USE_FSTI_BARREL),
		.USE_FSQRT_TWO_STAGE(USE_FSQRT_TWO_STAGE)) nanofpu_f03
	(
		.clk(clk), .rst_n(rst_n),
		.in_a(in_a[127:96]), .in_b(in_b[127:96]), .opcode(opcode[11:9]),
		.valid(valid[3]), .out(fpu_outs[127:96]), .ready(fpu_readies[3])
	);
	
	reg [1:0] f10_deps;
	reg [1:0] f11_deps;
	reg [1:0] f20_deps;
	
	wire f10_valid;
	wire f11_valid;
	wire f20_valid;
	assign f10_valid = fpu_enables[0] & &f10_deps;
	assign f11_valid = fpu_enables[1] & &f11_deps;
	assign f20_valid = fpu_enables[2] & &f20_deps;

	// F10 takes in F00 and F01 as inputs
	wire [31:0] f10_out;
	nanofpu #( 
		.ENABLE_FUNCS(ENABLE_F10),
		.USE_FMUL_DSP(USE_FMUL_DSP),
		.USE_FADDSUB_BARREL(USE_FADDSUB_BARREL),
		.USE_FSTI_BARREL(USE_FSTI_BARREL),
		.USE_FSQRT_TWO_STAGE(USE_FSQRT_TWO_STAGE)) nanofpu_f10
	(
		.clk(clk), .rst_n(rst_n),
		.in_a(fpu_outs[31:0]), .in_b(fpu_outs[63:32]), .opcode(opcode[14:12]),
		.valid(f10_valid), .out(f10_out), .ready(fpu_readies[4])
	);
	
	// F11 takes in F02 and F03 as inputs
	wire [31:0] f11_out;
	nanofpu #( 
		.ENABLE_FUNCS(ENABLE_F11),
		.USE_FMUL_DSP(USE_FMUL_DSP),
		.USE_FADDSUB_BARREL(USE_FADDSUB_BARREL),
		.USE_FSTI_BARREL(USE_FSTI_BARREL),
		.USE_FSQRT_TWO_STAGE(USE_FSQRT_TWO_STAGE)) nanofpu_f11
	(
		.clk(clk), .rst_n(rst_n),
		.in_a(fpu_outs[95:64]), .in_b(fpu_outs[127:96]), .opcode(opcode[17:15]),
		.valid(f11_valid), .out(f11_out), .ready(fpu_readies[5])
	);

	// F20 takes in F10 and F11 as inputs
	wire [31:0] f20_out;
	nanofpu #( 
		.ENABLE_FUNCS(ENABLE_F20),
		.USE_FMUL_DSP(USE_FMUL_DSP),
		.USE_FADDSUB_BARREL(USE_FADDSUB_BARREL),
		.USE_FSTI_BARREL(USE_FSTI_BARREL),
		.USE_FSQRT_TWO_STAGE(USE_FSQRT_TWO_STAGE)) nanofpu_f20
	(
		.clk(clk), .rst_n(rst_n),
		.in_a(f10_out), .in_b(f11_out), .opcode(opcode[20:18]),
		.valid(f20_valid), .out(f20_out), .ready(fpu_readies[6])
	);

	always @(posedge clk) begin
		// handle inner layers by accumulating the readies into pairs in fxy_deps[1:0]
		// This allows the FPUs to finish on their own time and the next level only starts
		// when both are ready
		f10_deps <= f10_deps | {fpu_readies[0], fpu_readies[1]};
		f11_deps <= f11_deps | {fpu_readies[2], fpu_readies[3]};
		f20_deps <= f20_deps | {fpu_readies[4], fpu_readies[5]};

		if (fpu_readies[0]) begin
			out[31:0]   <= fpu_outs[31:0];
		end
		if (fpu_readies[1]) begin
			out[63:32]   <= fpu_outs[63:32];
		end
		if (fpu_readies[2]) begin
			out[95:64]   <= fpu_outs[95:64];
		end
		if (fpu_readies[3]) begin
			out[127:96]   <= fpu_outs[127:96];
		end
		if (fpu_readies[4]) begin
			out[159:128]   <= f10_out;
		end
		if (fpu_readies[5]) begin
			out[191:160]   <= f11_out;
		end
		if (fpu_readies[6]) begin
			out[223:192]   <= f20_out;
		end

		// reset inners (fxy_valid is combinatorial so in the cycle where it goes high
		// we want to clear the deps so that valid goes low the next cycle)
		if (f10_valid) begin
			f10_deps <= 0;
		end
		if (f11_valid) begin
			f11_deps <= 0;
		end
		if (f20_valid) begin
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
		end	
	end
endmodule

`include "nanofpu.v"
