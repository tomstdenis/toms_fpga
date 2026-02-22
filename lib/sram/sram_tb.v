`timescale 1ns/1ps

module sram_tb();

	reg clk;
	reg rst_n;
	
	wire done;
	reg [7:0] data_in;
	reg data_in_valid;
	wire [7:0] data_out;
	reg data_out_read;
	wire data_out_empty;
	reg write_cmd;
	reg read_cmd;
	reg [5:0] read_cmd_size;
	reg [23:0] address;
	wire cs_pin;
	wire sck_pin;
	tri1 [3:0] sio_pin;
	reg [4:0] test_phase;
	
	spi_sram #(
		.CLK_FREQ_MHZ(50),
		.FIFO_DEPTH(32),
		.SRAM_ADDR_WIDTH(16),
		.DUMMY_BYTES(1),
		.CMD_READ(8'h03),
		.CMD_WRITE(8'h02),
		.CMD_EQIO(8'h38),
		.MIN_CPH_NS(50),
		.SPI_TIMER_BITS(2),
		.QPI_TIMER_BITS(1)) sram_dut(
			.clk(clk), .rst_n(rst_n),
			.done(done),
			.data_in(data_in), .data_in_valid(data_in_valid),
			.data_out(data_out), .data_out_read(data_out_read), .data_out_empty(data_out_empty),
			.write_cmd(write_cmd), .read_cmd(read_cmd), .read_cmd_size(read_cmd_size), .address(address),
			.sio_pin(sio_pin), .cs_pin(cs_pin), .sck_pin(sck_pin));
    // Parameters
    localparam CLK_PERIOD = 20;    // 50MHz
	
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Test Logic ---
    integer i;

	initial begin
        // Waveform setup
        $dumpfile("sram.vcd");
        $dumpvars(0, sram_tb);

		rst_n = 0;
		clk   = 0;
		data_in = 0;
		data_in_valid = 0;
		data_out_read = 0;
		write_cmd = 0;
		read_cmd = 0;
		read_cmd_size = 0;
		address = 0;

        // Reset system
        repeat(10) @(posedge clk);
        rst_n = 1;
        wait(done == 1);				// wait for init to finish

		// write 1 byte
		test_phase = 0;
		data_in = 8'h9A;
		data_in_valid = 1;
		@(posedge clk); #1;
		data_in_valid = 0;
		@(posedge clk); #1;
		expect_wptr(4);
		expect_rptr(0);

		// issue write
		test_phase = 1;
		address = 24'h5678;
		write_cmd = 1;
		@(posedge clk); #1;
		write_cmd = 0;
		@(posedge clk); #1;
		wait(done == 1);				// wait till send is done
		expect_wptr(3);
		expect_rptr(0);
		

		// write 2 byte
		test_phase = 2;
		data_in = 8'hAB;
		data_in_valid = 1;
		@(posedge clk); #1;
		data_in = 8'hCD;
		@(posedge clk); #1;
		data_in_valid = 0;
		@(posedge clk); #1;
		expect_wptr(2 + 3);
		expect_rptr(0);

		// issue write
		test_phase = 3;
		address = 24'h1234;
		write_cmd = 1;
		@(posedge clk); #1;
		write_cmd = 0;
		@(posedge clk); #1;
		wait(done == 1);				// wait till send is done
		expect_wptr(3);
		expect_rptr(0);
		
		// issue read of 16 bytes
		test_phase = 4;
		address = 24'hFEDC;
		read_cmd_size = 16;
		read_cmd = 1;
		@(posedge clk); #1;
		read_cmd = 0;
		@(posedge clk); #1;
		wait(done == 1);
		expect_read_cmd_wptr(1 + 2 + 1 + 16); // expecting the write pointer to be command + address + dummy + 16 byte read
		expect_rptr(1 + 2 + 1);      // expecting the read pointer to be command + address + dummy meaning rptr..wptr-1 is the payload

		// perform 16 reads from the fifo
		test_phase = 5;
		@(posedge clk); #1;
		data_out_read = 1;
		for (i = 0; i < 16; i++) begin
			expect_data_out_empty(0);
			@(posedge clk); #1;			 // wait into the next cycle
			expect_data(8'hFF);
			expect_read_cmd_wptr(1 + 2 + 1 + 16); // shouldn't change
			expect_rptr(1 + 2 + 1 + (i[6:0] + 1'b1));
		end
		expect_data_out_empty(1);
		data_out_read = 0;
		
        repeat(10) @(posedge clk);
        $finish;
	end
	

	task expect_wptr(input [6:0] ewptr);
		begin
			if (sram_dut.fifo_wptr != ewptr) begin
				$display("Was expecting fifo_wptr to be %d not %d", ewptr, sram_dut.fifo_wptr);
				repeat(16) @(posedge clk);
				$fatal;
			end
		end
	endtask

	task expect_read_cmd_wptr(input [6:0] ewptr);
		begin
			if (sram_dut.read_cmd_wptr != ewptr) begin
				$display("Was expecting read_cmd_wptr to be %d not %d", ewptr, sram_dut.read_cmd_wptr);
				repeat(16) @(posedge clk);
				$fatal;
			end
		end
	endtask

	task expect_rptr(input [6:0] erptr);
		begin
			if (sram_dut.fifo_rptr != erptr) begin
				$display("Was expecting fifo_rptr to be %d not %d", erptr, sram_dut.fifo_rptr);
				repeat(16) @(posedge clk);
				$fatal;
			end
		end
	endtask

	task expect_data(input [7:0] edata);
		begin
			if (data_out != edata) begin
				$display("Was expecting data_out to be %2h not %2h", edata, data_out);
				repeat(16) @(posedge clk);
				$fatal;
			end
		end
	endtask

	task expect_data_out_empty(input doe);
		begin
			if (data_out_empty != doe) begin
				$display("Was expecting data_out_empty to be %d not %d", doe, data_out_empty);
				repeat(16) @(posedge clk);
				$fatal;
			end
		end
	endtask

endmodule
