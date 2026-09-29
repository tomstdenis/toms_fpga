/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
`timescale 1ns/1ps

module fsqrt_tb();
	reg clk;
	reg rst_n;

    localparam CLK_PERIOD = 20;    //  50MHz
	
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Test Logic ---
	reg test_done = 0;
	reg test_pass = 0;
    // simple test go to address 16'h1234 and write 16 bytes starting at value 8'h55 increasing by 1 per bytes
    reg [3:0] test_state;
    reg [3:0] test_tag;
    
	initial begin
        // Waveform setup
        $dumpfile("fsqrt.vcd");
        $dumpvars(0, fsqrt_tb);

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
		TOTAL_TESTS = `NUM_OF_TESTS;
	
	reg [96+8-1:0] test_commands[0:TOTAL_TESTS-1];
	reg [31:0]     command_num;
	initial begin
		$readmemh("fpu.hex", test_commands);
	end
	wire [96+8-1:0] cur_command;
	assign cur_command = test_commands[command_num];
	
	wire [31:0] oper_a;
	wire [31:0] oper_b;
	wire [31:0] result;
	wire [7:0]  opcode;
	
	assign oper_a = cur_command[31:0];
	assign oper_b = cur_command[63:32];
	assign result = cur_command[95:64];
	assign opcode = cur_command[103:96];
	
	wire [31:0] fp_res;
	reg         fp_valid;
	wire        fp_ready;
	
	fsqrt fsqrt_dut(
		.clk(clk), .rst_n(rst_n),
		.in_a(oper_a),  .valid(fp_valid),
		.out(fp_res), .ready(fp_ready));

    localparam
		STATE_ISSUE	= 0,
		STATE_WAIT  = 1,
		STATE_DONE  = 2;
		
	reg [31:0] cycle_counter;
		
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
						test_state  <= STATE_WAIT;
						fp_valid    <= 1;
						cycle_counter <= 0;
					end
				STATE_WAIT:
					begin
						if (fp_ready) begin
							if (fp_res != result) begin
								test_done <= 1;
								test_pass <= 0;
								$display("Result mismatch fsqrt %x %x got==%x vs expected==%x", oper_a, oper_b, fp_res, result);
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

`include "fsqrt.v"
