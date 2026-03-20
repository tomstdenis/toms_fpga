`timescale 1ns/1ps

module sram_tb();
	localparam
		DUMMY = 6,
		DATA_WIDTH=32,
		SRAM_ADDR_WIDTH=24;

	reg clk;
	reg rst_n;
	
	wire done;
	reg [DATA_WIDTH-1:0] data_in;
	reg data_in_valid;
	wire [DATA_WIDTH-1:0] data_out;
	reg [3:0] data_be;
	reg write_cmd;
	reg read_cmd;
	reg [SRAM_ADDR_WIDTH-1:0] address;
	wire cs_pin;
	wire sck_pin;
	tri1 [3:0] sio_pin;
	reg [4:0] test_phase;
	
	reg sck_pin;
	reg cs_pin;
	reg [3:0] sio_en;
	wire [3:0] sio_dout;
	reg [3:0] sio_din;
	
	spi_sram #(
		.CLK_FREQ_MHZ(50), .DATA_WIDTH(DATA_WIDTH),
		.SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH), .DUMMY_BYTES(DUMMY), .CMD_READ(8'h03),
		.CMD_WRITE(8'h02), .CMD_EQIO(8'h38), .MIN_CPH_NS(50),
		.SPI_TIMER_BITS(4), .QPI_TIMER_BITS(2),
		.MIN_WAKEUP_NS(150000), .PSRAM_RESET(1), .CMD_RESETEN(8'h66), .CMD_RESET(8'h99)) flat(
			.clk(clk), .rst_n(rst_n),
			.done(done),
			.data_in(data_in), .data_in_valid(data_in_valid),
			.data_out(data_out), .data_be(data_be),
			
			.write_cmd(write_cmd), .read_cmd(read_cmd),
			.address(address), 
			.sio_din(sio_din), .sio_dout(sio_dout), .sio_en(sio_en),
			.cs_pin(cs_pin), .sck_pin(sck_pin));
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
        $dumpfile("sram.vcd");
        $dumpvars(0, sram_tb);

		X = 0;
		i = 0;
		j = 0;
		k = 0;
		rst_n = 0;
		clk   = 0;
		data_in = 0;
		data_in_valid = 0;
		write_cmd = 0;
		read_cmd = 0;
		address = 0;
		data_be = 4'b1111;

        // Reset system
        repeat(10) @(posedge clk);
        rst_n = 1;
        wait(done == 1);				// wait for init to finish

		// write 4 bytes
		test_phase = 0;
		data_in = 32'h12345678;
		data_in_valid = 1;
		write_cmd = 1;
		address = 'h1234;
		@(posedge clk); #1;
		data_in_valid = 0;
		write_cmd = 0;
		@(posedge clk); #1;
		wait(done == 1); #1;
		
		// write 2 bytes
		test_phase = 1;
		data_in = 32'h0000ABCD;
		data_in_valid = 1;
		write_cmd = 1;
		address = 'h1238;
		data_be = 4'b0011;
		@(posedge clk); #1;
		data_in_valid = 0;
		write_cmd = 0;
		@(posedge clk); #1;
		wait(done == 1); #1;

		// write 1 bytes
		test_phase = 2;
		data_in = 32'h000000EF;
		data_in_valid = 1;
		write_cmd = 1;
		address = 'h123A;
		data_be = 4'b0001;
		@(posedge clk); #1;
		data_in_valid = 0;
		write_cmd = 0;
		@(posedge clk); #1;
		wait(done == 1); #1;
		
		// read 4 bytes
		test_phase = 3;
		address = 'h1234;
		data_be = 4'b1111;
		read_cmd = 1;
		@(posedge clk); #1;
		read_cmd = 0;
		@(posedge clk); #1;
		wait(done == 1);
		if (data_out != 32'h12345678) begin
			$display("We expected 12345678 back not %h", data_out);
			$fatal;
		end

		// read 2 bytes
		test_phase = 4;
		address = 'h1238;
		data_be = 4'b0011;
		read_cmd = 1;
		@(posedge clk); #1;
		read_cmd = 0;
		@(posedge clk); #1;
		wait(done == 1);
		if (data_out != 32'h0000ABCD) begin
			$display("We expected 0000ABCD back not %h", data_out);
			$fatal;
		end

		// read 1 bytes
		test_phase = 5;
		address = 'h123A;
		data_be = 4'b0001;
		read_cmd = 1;
		@(posedge clk); #1;
		read_cmd = 0;
		@(posedge clk); #1;
		wait(done == 1);
		if (data_out != 32'h000000EF) begin
			$display("We expected 000000EF back not %h", data_out);
			$fatal;
		end

        repeat(10) @(posedge clk);
        $finish;
	end

endmodule
