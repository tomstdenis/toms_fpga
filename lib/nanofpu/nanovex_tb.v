/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
`timescale 1ns/1ps

`ifndef EXTERNAL_PARAM
`define HANDLE_INVALID_OP         1   // 1 == signals when an invalid opcode hits (0 == locks up)
`define USE_FMUL_DSP     		  1   // 0 == serial shifter, 1 == 36x36 DSP, 2 == 18x18 DSP, 3 == 2-bit serial shifter
`define USE_FMUL_TWO_STAGE_CMP    1   // 1 == pipeline the compares, helps timing
`define USE_FDIV_BARREL           1   // 0 == serial shifter, 1 == barrel shifter, lower latency, costs area
`define USE_FDIV_TWO_STAGE_CMP    1   // 1 == pipeline the compares, helps timing
`define USE_FDIV_2BIT_DIV         1   // Use 2-bit divider (22 cycles instead of 32)
`define USE_FADDSUB_BARREL        1   // Use barrel shifter for faddsub, lowers latency, costs area
`define USE_FADDSUB_TWO_STAGE_CMP 1   // Use pipelined comparison for sorting, helps timing
`define USE_FADDSUB_BIG_STEP      1   // Enable a 4-bit stride in the final norm, costs area
`define USE_FSTI_BARREL           1   // Use barrel shifter for fsti, lower latency, costs area
`define USE_FLDI_BIG_STEP         1   // use big step hunt, lowers latency, costs area
`define USE_FSQRT_STAGES 		  2   // 0 == 24 cycle SQRT, 1 == 48 cycles, 2 == 72 cycles (all + overhead)
`define USE_FPMUL16_DSP_MULT      1   // 0 == use 16x16 multipliers, 1 == use 32x32 multipliers										   
`endif

`include "nanofpu.vh"
module nanovex_tb();
	reg clk;
	reg rst_n;

    localparam CLK_PERIOD = 20;    //  50MHz
	
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Test Logic ---
	reg test_done = 0;
	reg test_pass = 0;
    reg [3:0] test_state;
    reg [3:0] test_tag;

	integer i, j;
    
	initial begin
        // Waveform setup
        $dumpfile("nanovex.vcd");
        $dumpvars(0, nanovex_tb);

		rst_n = 0;
		clk   = 0;

		while(test_done == 0) @(posedge clk);
		if (test_pass == 0) begin
			$display("Test failed\n");
			$fatal;
		end
		repeat(10) @(posedge clk);
        $finish;
	end
	
	localparam
		TOTAL_TESTS = `NUM_OF_TESTS,
        VEC_SIZE    = 22 * 32; // 32-bit inputs and output, and 5-bit opcodes (packed as 32-bits), all per nanovfpu
	
	reg [VEC_SIZE-1:0] test_commands[0:TOTAL_TESTS-1];
	reg [31:0]     command_num;
	initial begin
		$readmemh("fpu.hex", test_commands);
	end
	wire [VEC_SIZE-1:0] cur_command;
	assign cur_command = test_commands[command_num];
	
    reg [63:0] f00_in;
    reg [31:0] f00_out;
    reg [31:0] f00_opcode;
    reg [63:0] f01_in;
    reg [31:0] f01_out;
    reg [31:0] f01_opcode;
    reg [63:0] f02_in;
    reg [31:0] f02_out;
    reg [31:0] f02_opcode;
    reg [63:0] f03_in;
    reg [31:0] f03_out;
    reg [31:0] f03_opcode;
    reg [31:0] f10_out;
    reg [31:0] f10_opcode;
    reg [31:0] f11_out;
    reg [31:0] f11_opcode;
    reg [31:0] f20_out;
    reg [31:0] f20_opcode;

    always @(*) begin
        {
            f20_opcode, f20_out, 
            f11_opcode, f11_out, 
            f10_opcode, f10_out, 
            f03_opcode, f03_out, f03_in,
            f02_opcode, f02_out, f02_in,
            f01_opcode, f01_out, f01_in,
            f00_opcode, f00_out, f00_in
        } = cur_command;
    end

    wire [6:0]      fp_ready;
    reg [3:0]       fp_valid;
    wire [32*7-1:0] fp_out;
	
	nanovex #(
        .ENABLE_F00(`NANOFPU_FUNCS_ALL),
        .ENABLE_F01(`NANOFPU_FUNCS_ALL),
        .ENABLE_F02(`NANOFPU_FUNCS_ALL),
        .ENABLE_F03(`NANOFPU_FUNCS_ALL),
        .ENABLE_F10(`NANOFPU_FUNCS_ALL),
        .ENABLE_F11(`NANOFPU_FUNCS_ALL),
        .ENABLE_F20(`NANOFPU_FUNCS_ALL),
        .USE_FMUL_DSP(`USE_FMUL_DSP),
        .USE_FMUL_TWO_STAGE_CMP(`USE_FMUL_TWO_STAGE_CMP),
        .USE_FDIV_TWO_STAGE_CMP(`USE_FDIV_TWO_STAGE_CMP),
        .USE_FADDSUB_TWO_STAGE_CMP(`USE_FADDSUB_TWO_STAGE_CMP),
		.USE_FADDSUB_BIG_STEP(`USE_FADDSUB_BIG_STEP),
        .USE_FLDI_BIG_STEP(`USE_FLDI_BIG_STEP),
        .USE_FADDSUB_BARREL(`USE_FADDSUB_BARREL),
        .USE_FDIV_BARREL(`USE_FDIV_BARREL),
        .USE_FDIV_2BIT_DIV(`USE_FDIV_2BIT_DIV),
        .USE_FSTI_BARREL(`USE_FSTI_BARREL),
        .USE_FSQRT_STAGES(`USE_FSQRT_STAGES),
		.USE_FPMUL16_DSP_MULT(`USE_FPMUL16_DSP_MULT)
	) nanofpu_dut(
		.clk(clk), .rst_n(rst_n),
        .in_a({f03_in[31:0], f02_in[31:0], f01_in[31:0], f00_in[31:0]}),
        .in_b({f03_in[63:32], f02_in[63:32], f01_in[63:32], f00_in[63:32]}),
        .opcode({
                f20_opcode[4:0],
                f11_opcode[4:0], f10_opcode[4:0],
                f03_opcode[4:0], f02_opcode[4:0], f01_opcode[4:0], f00_opcode[4:0]
            }),
        .valid(fp_valid),
        .out(fp_out),
        .ready(fp_ready)
    );

    localparam
		STATE_ISSUE	= 0,
		STATE_WAIT  = 1,
		STATE_DONE  = 2;
		
	reg [31:0] cycle_counter;

    reg compare_ok;
    always @(*) begin
        compare_ok = 0;
        if (fp_out == {f20_out, f11_out, f10_out, f03_out, f02_out, f01_out, f00_out}) begin
            compare_ok = 1;
        end
    end
		
    always @(posedge clk) begin
		fp_valid         <= 0;
		cycle_counter    <= cycle_counter + 1;
        if (!rst_n) begin
            rst_n            <= 1'b1;
            command_num      <= 0;
            test_state       <= STATE_ISSUE;
        end else begin
            case (test_state)
				STATE_ISSUE:
					begin
						$display("Running command: %d, %x", command_num, cur_command);
						test_state    <= STATE_WAIT;
						fp_valid      <= 4'b1111;
						cycle_counter <= 0;
					end
				STATE_WAIT:
					begin
						if (fp_ready[6]) begin
							if (compare_ok != 1) begin
								test_done <= 1;
								test_pass <= 0;
								$display("Result mismatch...");
                                $display("f00 inputs: %h, %h", f00_in[31:0], f00_in[63:32]);
                                $display("f01 inputs: %h, %h", f01_in[31:0], f01_in[63:32]);
                                $display("f02 inputs: %h, %h", f02_in[31:0], f02_in[63:32]);
                                $display("f03 inputs: %h, %h", f03_in[31:0], f03_in[63:32]);
                                $display("f00: exp=%h vs rtl=%h, xor %h, opcode %h", f00_out, fp_out[32*1-1:32*0], f00_out ^ fp_out[32*1-1:32*0], f00_opcode);
                                $display("f01: exp=%h vs rtl=%h, xor %h, opcode %h", f01_out, fp_out[32*2-1:32*1], f01_out ^ fp_out[32*2-1:32*1], f01_opcode);
                                $display("f02: exp=%h vs rtl=%h, xor %h, opcode %h", f02_out, fp_out[32*3-1:32*2], f02_out ^ fp_out[32*3-1:32*2], f02_opcode);
                                $display("f03: exp=%h vs rtl=%h, xor %h, opcode %h", f03_out, fp_out[32*4-1:32*3], f03_out ^ fp_out[32*4-1:32*3], f03_opcode);
                                $display("f10: exp=%h vs rtl=%h, xor %h, opcode %h", f10_out, fp_out[32*5-1:32*4], f10_out ^ fp_out[32*5-1:32*4], f10_opcode);
                                $display("f11: exp=%h vs rtl=%h, xor %h, opcode %h", f11_out, fp_out[32*6-1:32*5], f11_out ^ fp_out[32*6-1:32*5], f11_opcode);
                                $display("f20: exp=%h vs rtl=%h, xor %h, opcode %h", f20_out, fp_out[32*7-1:32*6], f20_out ^ fp_out[32*7-1:32*6], f20_opcode);
							end else begin
								command_num <= command_num + 1;
								test_state  <= (command_num == TOTAL_TESTS-1) ? STATE_DONE : STATE_ISSUE;
							end
						end
					end
				STATE_DONE:
					begin
						test_done <= 1;
						test_pass <= 1;
					end
			endcase
        end
    end
endmodule

`include "nanovex.v"
