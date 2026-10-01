`default_nettype none
`timescale 1ns/1ps

module top(
	input clk,
	input rx,
	output tx);
	
	reg rst_n;

	localparam
		freq = `FREQ * 1_000_000,
		baud = 1_000_000,
		baudwidth = $clog2(freq / baud);
		
	wire [baudwidth-1:0] bauddiv = freq / baud;
	reg uart_tx_start;
	reg uart_rx_read;
	reg [7:0] uart_tx_data_in;
	wire uart_tx_fifo_full;
	wire uart_rx_ready;
	wire [7:0] uart_rx_byte;
	wire pll_clk;
	wire plllock;
	
	initial begin
		rst_n = 0;
	end
	
	pll mypll(.clkin(clk), .clkout0(pll_clk), .locked(plllock));
	uart #(.BAUD_WIDTH(baudwidth), .FIFO_DEPTH(4), .RX_ENABLE(1), .TX_ENABLE(1)) myuart(
		.clk(pll_clk), .rst_n(rst_n),
		.baud_div(bauddiv), 
		.uart_tx_start(uart_tx_start), .uart_tx_data_in(uart_tx_data_in), .uart_tx_pin(tx), .uart_tx_fifo_full(uart_tx_fifo_full),
		.uart_rx_pin(rx), .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready), .uart_rx_byte(uart_rx_byte));

    
	localparam
		TOTAL_TESTS = `NUMTESTS;
	
	reg [96+8-1:0] test_commands[0:TOTAL_TESTS-1];
	reg [31:0]     command_num;
	initial begin
		$readmemh("fpu.hex", test_commands);
	end
	wire [96+8-1:0] cur_command;
	reg [96+8-1:0]  cur_command_latched;
	assign cur_command = test_commands[command_num];
	
	wire [31:0] oper_a;
	wire [31:0] oper_b;
	wire [31:0] result;
	wire [7:0]  opcode;
	
	assign oper_a = cur_command_latched[31:0];
	assign oper_b = cur_command_latched[63:32];
	assign result = cur_command_latched[95:64];
	assign opcode = cur_command_latched[103:96];
	
	wire [31:0] fp_res;
	reg         fp_valid;
	wire        fp_ready;
	
	nanofpu #(
		.USE_FADDSUB_BARREL(1),
		.USE_FSTI_BARREL(1),
		.USE_FMUL_DSP(2),
		.USE_FSQRT_STAGES(2)
	) nanofpu_dut(
		.clk(pll_clk), .rst_n(rst_n),
		.in_a(oper_a), .in_b(oper_b), .opcode(opcode[3:0]), .valid(fp_valid),
		.out(fp_res), .ready(fp_ready));

    reg [3:0] test_state;
    reg       test_pass;
    localparam
		STATE_ISSUE	= 0,
		STATE_WAIT  = 1,
		STATE_DONE  = 2,
		STATE_DELAY = 3,
		STATE_DELAY2 = 4;
		
    always @(posedge pll_clk) begin
		fp_valid         <= 0;
		uart_tx_start    <= 0;
		uart_rx_read     <= 0;
		
        if (!rst_n) begin
            rst_n            <= 1'b1;
            command_num      <= 0;
            test_state       <= STATE_DELAY;
            test_pass        <= 0;
        end else begin
            case (test_state)
				STATE_DELAY: begin
					test_state          <= STATE_DELAY2;
				end
				STATE_DELAY2: begin
					test_state          <= STATE_ISSUE;
					cur_command_latched <= cur_command;
				end
				STATE_ISSUE:
					begin
						test_state      <= STATE_WAIT;
						fp_valid        <= 1;
					end
				STATE_WAIT:
					begin
						if (fp_ready) begin
							if (fp_res != result) begin
								test_pass <= 0;
								test_state <= STATE_DONE;
							end else begin
								test_pass <= 1;
								command_num <= command_num + 1;
								test_state  <= (command_num == TOTAL_TESTS-1) ? STATE_DONE : STATE_DELAY;
							end
						end
					end
				STATE_DONE:
					begin
						if (~uart_tx_fifo_full) begin
							uart_tx_data_in <= test_pass ? 8'h55 : 8'hAA;
							uart_tx_start   <= 1;
							test_state      <= STATE_DELAY;
							command_num     <= 0;
						end
					end
			endcase
        end
    end
endmodule
