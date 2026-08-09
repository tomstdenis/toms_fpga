/* verilator lint_off WIDTHEXPAND */
`timescale 1ns/1ps

module nanosram_tb();
	localparam
		DUMMY = 3,
		SRAM_ADDR_WIDTH = 24;

	reg [4:0] test_phase;
	reg clk;
	reg rst_n;
	
    // Parameters
    localparam CLK_PERIOD = 20;    //  50MHz
	
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    reg [23:0] sram_addr;
    reg [7:0]  sram_din;
    wire [7:0] sram_dout;
    reg        sram_wr_en;
    reg        sram_start_trans;
    reg        sram_shift_data;
    wire       sram_ready;
    wire       sram_busy;
    wire       sram_idle;

    wire [3:0] sio_din;
    wire [3:0] sio_dout;
    wire       sio_en;
    wire       cs_pin;
	wire	   sck_pin;

    nanosram dut(
        .clk(clk), .rst_n(rst_n),
        .addr(sram_addr), .data_in(sram_din), .data_out(sram_dout), .wr_en(sram_wr_en),
        .start_trans(sram_start_trans), .ready(sram_ready), .shift_data(sram_shift_data), .busy(sram_busy), .idle(sram_idle),
        .sio_din(sio_din), .sio_dout(sio_dout), .sio_en(sio_en), .cs_pin(cs_pin), .sck_pin(sck_pin));

    // --- Test Logic ---
    integer i;
    integer j;
    integer k;
	integer X;
	reg test_rst = 0;
	reg test_done = 0;
	reg test_pass = 0;
    // simple test go to address 16'h1234 and write 16 bytes starting at value 8'h55 increasing by 1 per bytes
    reg [7:0] test_byte;
    reg [3:0] test_state;
    reg [3:0] test_tag;
    reg [1:0] test_cycle;

	initial begin
        // Waveform setup
        $dumpfile("nanosram.vcd");
        $dumpvars(0, nanosram_tb);

		X = 0;
		i = 0;
		j = 0;
		k = 0;
		rst_n = 0;
		clk   = 0;
		sram_shift_data  = 0;
		sram_start_trans = 0;
		sram_wr_en       = 0;

        // Reset system
        repeat(10) @(posedge clk);
        rst_n = 1;
        wait(sram_idle == 1);
        test_rst = 1;

		while(test_done == 0) @(posedge clk);
		if (test_pass == 0) begin
			$display("Test failed\n");
			$fatal;
		end
		repeat(10) @(posedge clk);
        $finish;
	end
	
    localparam
        STATE_START_WRITE = 0,
        STATE_LOOP_WRITE  = 1,
        STATE_START_READ  = 2,
        STATE_LOOP_READ   = 3;

    always @(posedge clk) begin
        if (!test_rst) begin
            test_rst         <= 1'b1;
            sram_start_trans <= 1'b0;
            sram_shift_data  <= 1'b0;
            sram_wr_en       <= 1'b0;
            test_state       <= STATE_START_WRITE;
            test_cycle       <= 0;
        end else begin
            case (test_state)
                STATE_START_WRITE:
                    begin
                        if (sram_idle) begin
                            sram_addr        <= 16'h1234;
                            sram_din         <= 8'h55;
                            sram_start_trans <= 1'b1;
                            sram_wr_en       <= 1'b1;
                        end
                        if (sram_start_trans & sram_ready) begin
                            test_state            <= STATE_LOOP_WRITE;
                            sram_shift_data       <= 1'b1;                      // NS is in WORK_MODE state
                        end
                    end
                STATE_LOOP_WRITE:                                               // by this point we're in SHIFT_QUAD
                    begin
                        sram_shift_data <= 1'b0;
                        if (sram_ready & !sram_shift_data) begin
                            if (sram_addr == (16'h1234 + 16'd16)) begin
                                sram_shift_data  <= 0;
                                sram_start_trans <= 0;
                                test_state       <= STATE_START_READ;
                            end else begin
                                sram_addr        <= sram_addr + 1'b1;
                                sram_din         <= sram_din + 1'b1;
                                sram_shift_data  <= 1'b1;
                            end
                        end
                    end
                STATE_START_READ:
                    begin
                        if (sram_idle) begin
                            sram_addr        <= 16'h1234;
                            sram_wr_en       <= 1'b0;
                            sram_start_trans <= 1'b1;
                        end
                        if (sram_start_trans & sram_ready) begin
                            test_state      <= STATE_LOOP_READ;
                            sram_shift_data <= 1'b1;
                        end
                    end
                STATE_LOOP_READ:                                               // by this point we're in SHIFT_QUAD
                    begin
                        sram_shift_data <= 1'b0;
                        if (sram_ready & !sram_shift_data) begin
                            if (sram_addr == (16'h1234 + 16'd16)) begin
								test_done <= 1'b1;
								test_pass <= 1'b1;
								sram_start_trans <= 1'b0;
                            end else begin
                                if (sram_dout == 8'h55 + sram_addr - 16'h1234) begin
                                    sram_addr        <= sram_addr + 1'b1;
                                    sram_shift_data  <= 1'b1;
                                end else begin 
                                    sram_shift_data  <= 1'b0;
									test_done <= 1'b1;
									test_pass <= 1'b0;
									sram_start_trans <= 1'b0;
                                end
                            end
                        end
                    end
            endcase
        end
    end

endmodule
