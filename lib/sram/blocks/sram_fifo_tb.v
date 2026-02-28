`timescale 1ns/1ps

module sram_fifo_tb();
	localparam
		DUMMY = 6;

	reg clk;
	reg rst_n;
	
	wire done;
	reg [31:0] data_in;
	reg data_in_valid;
	wire [31:0] data_out;
	reg data_out_read;
	reg [3:0] data_be;
	wire data_out_empty;
	reg write_cmd;
	reg read_cmd;
	reg [5:0] read_cmd_size;
	reg [23:0] address;
	wire cs_pin;
	wire sck_pin;
	tri1 [3:0] sio_pin;
	reg [4:0] test_phase;
	
	spi_sram_fifo #(
		.CLK_FREQ_MHZ(50),
		.FIFO_DEPTH(32),
		.SRAM_ADDR_WIDTH(16),
		.DUMMY_BYTES(DUMMY),
		.CMD_READ(8'h03),
		.CMD_WRITE(8'h02),
		.CMD_EQIO(8'h38),
		.MIN_CPH_NS(0),
		.SPI_TIMER_BITS(2),
		.QPI_TIMER_BITS(1)) sram_dut(
			.clk(clk), .rst_n(rst_n),
			.done(done),
			.data_in(data_in), .data_in_valid(data_in_valid), .data_be(data_be),
			.data_out(data_out), .data_out_read(data_out_read), .data_out_empty(data_out_empty),
			.write_cmd(write_cmd), .read_cmd(read_cmd), .read_cmd_size(read_cmd_size), .address(address),
			.sio_pin(sio_pin), .cs_pin(cs_pin), .sck_pin(sck_pin));
    // Parameters
    localparam CLK_PERIOD = 20;    //  50MHz
	
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Test Logic ---
    integer i;
    integer j;
    integer k;
	integer X;

	initial begin
        // Waveform setup
        $dumpfile("sram_fifo.vcd");
        $dumpvars(0, sram_fifo_tb);

		X = 0;
		i = 0;
		rst_n = 0;
		clk   = 0;
		data_in = 0;
		data_in_valid = 0;
		data_out_read = 0;
		write_cmd = 0;
		read_cmd = 0;
		read_cmd_size = 0;
		address = 0;
		data_be = 4'b0001;

        // Reset system
        repeat(10) @(posedge clk);
        rst_n = 1;
        wait(done == 1);				// wait for init to finish

		// write 1 byte
		test_phase = 0;
		data_in = 32'hC3;
		data_in_valid = 1;
		@(posedge clk); #1;
		data_in_valid = 0;
		@(posedge clk); #1;
		expect_wptr(4);
		expect_rptr(0);

		// issue write
		test_phase = 1;
		address = 24'h1236;
		write_cmd = 1;
		@(posedge clk); #1;
		write_cmd = 0;
		@(posedge clk); #1;
		wait(done == 1);				// wait till send is done
		expect_wptr(3);
		expect_rptr(0);
		

		// write 2 byte
		test_phase = 2;
		data_in = 32'hAB;
		data_in_valid = 1;
		@(posedge clk); #1;
		data_in = 32'hCD;
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
		
		// issue read of X bytes
		X = 3;
		test_phase = 4;
		address = 24'h1234;
		read_cmd_size = X[5:0];
		read_cmd = 1;
		@(posedge clk); #1;
		read_cmd = 0;
		@(posedge clk); #1;
		wait(done == 1);
		expect_read_cmd_wptr(1 + 2 + DUMMY + X[6:0]); // expecting the write pointer to be command + address + dummy + 16 byte read
		expect_rptr(1 + 2 + DUMMY);      // expecting the read pointer to be command + address + dummy meaning rptr..wptr-1 is the payload

		// perform X reads from the fifo
		test_phase = 5;
		@(posedge clk); #1;
		data_out_read = 1;
		for (i = 0; i < X; i++) begin
			case (i)
				0: expect_data(32'hAB);
				1: expect_data(32'hCD);
				2: expect_data(32'hC3);
			endcase
			expect_data_out_empty(0);
			@(posedge clk); #1;			 // wait into the next cycle
			expect_read_cmd_wptr(1 + 2 + DUMMY + X[6:0]); // shouldn't change
			expect_rptr(1 + 2 + DUMMY + (i[6:0] + 1'b1));
		end
		expect_data_out_empty(1);
		data_out_read = 0;
		
		// try a 16-bit read
		test_phase = 6;
		issue_read(24'h1234, 32'h0000CDAB, 4'b0011, 2);
		
		// try a 32-bit write
		test_phase = 7;
		issue_write(24'h2000, 32'h12345678, 4'b1111);
		
		// try reading it back
		test_phase = 8;
		issue_read(24'h2000, 32'h12345678, 4'b1111, 4);
		
		// and as 16-bit with offset so we're expecting 3456
		test_phase = 9;
		issue_read(24'h2001, 32'h00003456, 4'b0011, 2);
		
		// single byte
		test_phase = 10;
		issue_read(24'h2003, 32'h00000012, 4'b0001, 1);

		// try out all depths of FIFO for 8, 16, and 32-bit operations
		test_phase = 11;
		for (i = 1; i <= 32; i++) begin
			issue_write_loop(24'h3000, 32'h01 * i, 4'b0001, i[5:0], 32'hff);
			issue_read_loop(24'h3000, 32'h01 * i, 4'b0001, i[5:0], 32'hff, 1);
		end

		test_phase = 12;
		for (i = 1; i <= 16; i++) begin
			issue_write_loop(24'h4000, 32'h0101 * i, 4'b0011, i[5:0], 32'hffff);
			issue_read_loop(24'h4000, 32'h0101 * i, 4'b0011, i[5:0] * 2, 32'h0000ffff, 2);
		end

		test_phase = 13;
		for (i = 1; i <= 8; i++) begin
			issue_write_loop(24'h5000, 32'h01010101 * i, 4'b1111, i[5:0], 32'hffffffff);
			issue_read_loop(24'h5000, 32'h01010101 * i, 4'b1111, i[5:0] * 4, 32'hffffffff, 4);
		end

        repeat(10) @(posedge clk);
        $finish;
	end

	// repeated writes of a datum (writes w_data count times...)
	task issue_write_loop(input [23:0] w_addr, input [31:0] w_data, input [3:0] w_be, input [5:0] count, input [31:0] mask );
		integer x;
		begin
			for (x = 0; x < count; x++) begin
				// write to fifo (we change the value per loop so we're not stuff the same bytes in
				data_in = w_data + (32'h12345678 & mask) * x;
				data_be = w_be;
				data_in_valid = 1;
				@(posedge clk); #1;
			end
			
			// issue SRAM write
			data_in_valid = 0;
			read_cmd = 0;
			write_cmd = 1;
			address = w_addr;
			@(posedge clk); #1;
			
			// wait for done
			write_cmd = 0;
			wait(done == 1);
		end
	endtask
	
	task issue_read_loop(input [23:0] r_addr, input [31:0] e_data, input [3:0] r_be, input [5:0] readsize, input [31:0] mask, input [31:0] bytes);
		integer x;
		begin
			// issue read
			read_cmd_size = readsize;
			read_cmd = 1;
			address = r_addr;
			data_be = r_be;
			@(posedge clk); #1;
			// wait for done
			read_cmd = 0;
			@(posedge clk); #1;
			wait(done == 1);
			for (x = 0; x < readsize; x += bytes) begin
				// read from fifo
				if (data_out !== ((e_data + (32'h12345678 & mask) * (x/bytes)) & mask)) begin
					$display("Read value (%h) not expected (%h) at %h (%d)", data_out,  ((e_data + x/bytes) & mask), r_addr, sram_dut.fifo_rptr);
					$fatal;
				end
				// consume word
				data_out_read = 1;
				@(posedge clk); #1;
			end
			data_out_read = 0;
			@(posedge clk); #1;
		end
	endtask

	
	task issue_write(input [23:0] w_addr, input [31:0] w_data, input [3:0] w_be );
		begin
			// write to fifo
			data_in = w_data;
			data_be = w_be;
			data_in_valid = 1;
			@(posedge clk); #1;
			
			// issue SRAM write
			data_in_valid = 0;
			read_cmd = 0;
			write_cmd = 1;
			address = w_addr;
			@(posedge clk); #1;
			
			// wait for done
			write_cmd = 0;
			wait(done == 1);
		end
	endtask
	
	task issue_read(input [23:0] r_addr, input [31:0] e_data, input [3:0] r_be, input [5:0] readsize );
		begin
			// issue read
			read_cmd_size = readsize;
			read_cmd = 1;
			address = r_addr;
			data_be = r_be;
			@(posedge clk); #1;
			// wait for done
			read_cmd = 0;
			@(posedge clk); #1;
			wait(done == 1);
			// read from fifo
			if (data_out !== e_data) begin
				$display("Read value (%h) not expected (%h) at %h (%d)", data_out, e_data, r_addr, sram_dut.fifo_rptr);
				$fatal;
			end
			// consume word
			data_out_read = 1;
			@(posedge clk); #1;
			data_out_read = 0;
			@(posedge clk); #1;
		end
	endtask

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

	task expect_data(input [31:0] edata);
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
