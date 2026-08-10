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
    wire       sram_busy;
    wire       sram_idle;
    wire	   sram_ready;
    wire       sram_read_strobe;
    wire       sram_write_strobe;

    wire [3:0] sio_din;
    wire [3:0] sio_dout;
    wire       sio_en;
    wire       cs_pin;
	wire	   sck_pin;

    nanosram dut(
        .clk(clk), .rst_n(rst_n),
        .addr(sram_addr), .data_in(sram_din), .data_out(sram_dout), .wr_en(sram_wr_en),
        .start_trans(sram_start_trans), .busy(sram_busy), .idle(sram_idle), .ready(sram_ready),
        .read_strobe(sram_read_strobe), .write_strobe(sram_write_strobe),
        .sio_din(sio_din), .sio_dout(sio_dout), .sio_en(sio_en), .cs_pin(cs_pin), .sck_pin(sck_pin));

    // --- Test Logic ---
	reg test_rst = 0;
	reg test_done = 0;
	reg test_pass = 0;
    // simple test go to address 16'h1234 and write 16 bytes starting at value 8'h55 increasing by 1 per bytes
    reg [7:0] test_byte;
    reg [3:0] test_state;
    reg [3:0] test_tag;
    reg [5:0] test_cycle;

	initial begin
        // Waveform setup
        $dumpfile("nanosram.vcd");
        $dumpvars(0, nanosram_tb);

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
        STATE_START_WRITE = 0,
        STATE_LOOP_WRITE  = 1,
        STATE_START_READ  = 2,
        STATE_LOOP_READ   = 3;

    always @(posedge clk) begin
        if (!rst_n) begin
            rst_n            <= 1'b1;
            sram_start_trans <= 1'b0;
            sram_wr_en       <= 1'b0;
            test_state       <= STATE_START_WRITE;
            test_cycle       <= 0;
        end else begin
            test_cycle <= test_cycle + 1;
            case (test_state)
                STATE_START_WRITE:
                    begin
                        if (sram_idle) begin
                            test_cycle       <= 0;
                            sram_addr        <= 16'h1234;
                            sram_din         <= 8'h2A;
                            sram_start_trans <= 1'b1;
                            sram_wr_en       <= 1'b1;
                            test_state       <= STATE_LOOP_WRITE;
                        end
                    end
                STATE_LOOP_WRITE:                                               // by this point we're in SHIFT_QUAD
                    begin
                        if (sram_ready & sram_write_strobe) begin
                            // the write strobe occurs BEFORE the current byte is finished so if we lower
                            // start_trans the FSM will stop writing with the current byte being shifted out
                            if (sram_addr == (16'h1234 + 16'd15)) begin
                                sram_start_trans <= 0;
                                test_state       <= STATE_START_READ;
                            end else begin
                                sram_addr        <= sram_addr + 1'b1;
                                sram_din         <= sram_din + 1'b1;
                            end
                        end
                    end
                STATE_START_READ:
                    begin
                        if (sram_idle) begin
                            test_cycle       <= 0;
							sram_start_trans <= 1'b1;
                            sram_addr        <= 16'h1234;
                            sram_wr_en       <= 1'b0;
                            test_state       <= STATE_LOOP_READ;
                        end
                    end
                STATE_LOOP_READ:                                               // by this point we're in SHIFT_QUAD
                    begin
                        if (sram_ready & sram_read_strobe) begin
							// we've read the last byte, end the test.
                            if (sram_addr == (16'h1234 + 16'd16)) begin
								test_done <= 1'b1;
								test_pass <= 1'b1;
                            end else begin
								// we're at the 2nd last byte turn off the transaction so it stops reading once it reads
								// byte 16.  Unlike write_strobe the read_strobe occurs on the cycle the latest byte is
                                // valid so we need to lower the start_trans reg on the count-1 byte.
								if (sram_addr == (16'h1234 + 16'd15)) begin
									sram_start_trans <= 1'b0;
								end

								// compare the bytes
                                if (sram_dout == ((8'h2A + sram_addr - 8'h34) & 8'hFF)) begin
                                    sram_addr <= sram_addr + 1'b1;
                                end else begin
									$display("Got %h expected %h", sram_dout, 8'h2A + sram_addr - 16'h1234);
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
