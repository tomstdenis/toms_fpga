// sizing template for ICE40 FULL (-fpmul since it's currently impractical)
`include "nanofpu.vh"
module ice40_full(
    input wire clk,
    input wire rst_n,

    input wire [31:0] oper_a,
    input wire [31:0] oper_b,
    input wire [3:0]  opcode,
    input wire        fp_valid,
    output wire [31:0] fp_res,
    output wire        fp_ready
);

	nanofpu #(
	    .ENABLE_FUNCS(`NANOFPU_FUNCS_ALL & ~`NANOFPU_FL_FPMUL),
        .USE_FMUL_DSP(0),
        .USE_FMUL_TWO_STAGE_CMP(1),
        .USE_FDIV_TWO_STAGE_CMP(1),
        .USE_FADDSUB_TWO_STAGE_CMP(1),
		.USE_FADDSUB_BIG_STEP(0),
        .USE_FLDI_BIG_STEP(0),
        .USE_FADDSUB_BARREL(1),
        .USE_FDIV_BARREL(0),
        .USE_FSTI_BARREL(0),
        .USE_FSQRT_STAGES(2),
		.USE_FPMUL16_DSP_MULT(0)
	) nanofpu_dut(
		.clk(clk), .rst_n(rst_n),
		.in_a(oper_a), .in_b(oper_b), .opcode(opcode[3:0]), .valid(fp_valid),
		.out(fp_res), .ready(fp_ready));
endmodule

`include "nanofpu.v"
