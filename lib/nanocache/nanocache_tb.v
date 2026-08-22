/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
`timescale 1ns/1ps

module nanocache_tb();
	reg clk;
	reg rst_n;
	
    // Parameters
	localparam SRAM_ADDR_WIDTH = 24;
    localparam CLK_PERIOD = 20;    //  50MHz
	
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

	reg [7:0]                 nc_data_in;
	reg [SRAM_ADDR_WIDTH-1:0] nc_data_addr;
	reg                       nc_data_wr_en;
	wire [7:0]                nc_data_out;
	reg                       nc_valid;
	wire                      nc_ready;
	wire                      nc_idle;

    wire [3:0] sio_din;
    wire [3:0] sio_dout;
    wire       sio_en;
    wire       cs_pin;
	wire	   sck_pin;

	// nanocache
	nanocache #(.WAKEUP_DELAY_US(0), .HANGUP_DELAY_NS(0)) nc_dut (
		.clk(clk), .rst_n(rst_n),
		.data_in(nc_data_in), .data_out(nc_data_out), .data_addr(nc_data_addr), .data_wr_en(nc_data_wr_en),
		.valid(nc_valid), .ready(nc_ready), .idle(nc_idle),
		.sio_din(sio_din), .sio_dout(sio_dout), .sio_en(sio_en), .cs_pin(cs_pin), .sck_pin(sck_pin)
	);

    // --- Test Logic ---
	reg test_done = 0;
	reg test_pass = 0;
    // simple test go to address 16'h1234 and write 16 bytes starting at value 8'h55 increasing by 1 per bytes
    reg [3:0] test_state;
    reg [3:0] test_tag;
    
    // the current test command being executed
    reg [15:0] command_num;
    reg [3:0]  command_op;
    reg [1:0]  command_burst_len;
    reg [23:0] command_addr;
    reg        command_wr_en;
    reg [31:0] command_data;
    
    localparam
		command_op_read  = 4'h8,
		command_op_write = 4'h4,
		command_op_halt  = 4'h2;

	initial begin
        // Waveform setup
        $dumpfile("nanocache.vcd");
        $dumpvars(0, nanocache_tb);

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
	
	reg [63:0] test_commands[0:32767];
	wire [63:0] cur_command;
	assign cur_command = test_commands[command_num];
	
	initial begin
		$readmemh("trace.hex", test_commands);
	end

    localparam
		STATE_START_COMMAND        = 0,
		STATE_START_READ           = 1,
		STATE_START_WRITE          = 2,
		STATE_HALT                 = 3;
		
    always @(posedge clk) begin
        if (!rst_n) begin
            rst_n            <= 1'b1;
            command_num      <= 0;
            test_state       <= STATE_START_COMMAND;
            nc_valid         <= 0;
            nc_data_wr_en    <= 0;
        end else begin
            case (test_state)
				STATE_START_COMMAND:
					begin
						$display("Running command: %d, %x", command_num, cur_command);
						command_num       <= command_num + 1;
						command_op        <= cur_command[63:60];
						command_burst_len <= cur_command[59:56];
						command_addr      <= cur_command[55:32];
						command_data      <= cur_command[31:0];
						case (cur_command[63:60])
							command_op_read:   test_state <= STATE_START_READ;
							command_op_write:  test_state <= STATE_START_WRITE;
							command_op_halt: 
								begin
									test_state <= STATE_HALT;
									test_pass  <= 1'b1;
								end
						endcase
					end
				STATE_START_READ:
					begin
						nc_valid <= (command_burst_len != 0)? nc_valid : 1'b0;
						if (!nc_valid & nc_idle) begin
							$display("READ in idle");
							nc_valid      <= 1;
							nc_data_wr_en <= 0;
							nc_data_addr  <= command_addr;
						end
						if (nc_ready) begin
							$display("READ in ready");
							command_data      <= {command_data[23:0], 8'b0};
							command_burst_len <= command_burst_len - 1;
							if (command_burst_len == 0) begin
								test_state <= STATE_START_COMMAND;					// jump to start on last byte
							end
							if (command_burst_len == 1) begin
								nc_valid   <= 1'b0;                                 // turn off valid one cycle EARLY to avoid over-writing past the burst
							end
							// every cycle this is high we have data
							$display("Read byte: %x", nc_data_out);
							if (nc_data_out !== command_data[31:24]) begin
								$display("Read back failed got %x expected %x", nc_data_out, command_data[31:24]);
								test_state <= STATE_HALT;
								nc_valid   <= 1'b0;
							end
						end
					end
				STATE_START_WRITE: // start a write burst
					begin
						nc_valid   <= (command_burst_len != 0) ? nc_valid : 1'b0;   // We need to stop writing before the first ready if 1 byte stride
						nc_data_in <= command_data[31:24];							// this is so data_in is set for when ready goes high first
						if (!nc_valid & nc_idle) begin								// only program job once
							$display("WRITE in idle");
							nc_valid      <= 1'b1;
							nc_data_wr_en <= 1'b1;
							nc_data_in    <= command_data[31:24];
							nc_data_addr  <= command_addr;
							command_data <= { command_data[23:0], 8'b0 };
						end
						if (nc_ready) begin											// ready strobe
							$display("WRITE in ready");
							// every cycle this is high we shift command_data
							command_data      <= { command_data[23:0], 8'b0 };		// shift data up
							nc_data_in        <= command_data[23:16];				// by the first ready we've already processed the 2nd byte so load the third onwards
							command_burst_len <= command_burst_len - 1;
							if (command_burst_len == 0) begin
								test_state <= STATE_START_COMMAND;                  // jump to start when done last byte
							end
							if (command_burst_len == 1) begin
								nc_valid   <= 1'b0;                                 // turn off valid one cycle EARLY to avoid over-writing past the burst
							end
						end
					end
				STATE_HALT:
					begin
						$display("Halted");
						test_done <= 1'b1;
					end
            endcase
        end
    end
endmodule
