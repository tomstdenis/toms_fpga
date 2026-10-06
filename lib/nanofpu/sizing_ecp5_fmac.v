// sizing template for ECP5 FMAC
`include "nanofpu.vh"
module ecp5_fmac(
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
	    .ENABLE_FUNCS(`NANOFPU_FUNCS_MULADD),
        .USE_FMUL_DSP(2),
        .USE_FMUL_TWO_STAGE_CMP(1),
        .USE_FADDSUB_TWO_STAGE_CMP(1),
		.USE_FADDSUB_BIG_STEP(1),
        .USE_FADDSUB_BARREL(1),
	) nanofpu_dut(
		.clk(clk), .rst_n(rst_n),
		.in_a(oper_a), .in_b(oper_b), .opcode(opcode[3:0]), .valid(fp_valid),
		.out(fp_res), .ready(fp_ready));
endmodule

`include "nanofpu.v"
