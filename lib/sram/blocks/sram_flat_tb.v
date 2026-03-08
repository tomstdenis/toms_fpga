`timescale 1ns/1ps

module sram_flat_tb();
	localparam
		DUMMY = 6,
		DATA_WIDTH=32,
		SRAM_ADDR_WIDTH=16;

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

	spi_sram_flat #(
		.CLK_FREQ_MHZ(25), .DATA_WIDTH(DATA_WIDTH),
		.SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH), .DUMMY_BYTES(DUMMY), .CMD_READ(8'h03),
		.CMD_WRITE(8'h02), .CMD_EQIO(8'h38), .MIN_CPH_NS(50),
		.SPI_TIMER_BITS(2), .QPI_TIMER_BITS(1)) flat(
			.clk(clk), .rst_n(rst_n),
			.done(done),
			.data_in(data_in), .data_in_valid(data_in_valid),
			.data_out(data_out), .data_be(data_be),
			
			.write_cmd(write_cmd), .read_cmd(read_cmd),
			.address(address), .sio_pin(sio_pin), .cs_pin(cs_pin), .sck_pin(sck_pin));
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
        $dumpfile("sram_flat.vcd");
        $dumpvars(0, sram_flat_tb);

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

		// write 1 byte
		test_phase = 0;

        repeat(10) @(posedge clk);
        $finish;
	end

endmodule
