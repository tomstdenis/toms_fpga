`timescale 1ns/1ps

module spi_sram_mem_tb();

	reg clk;
	reg rst_n;
	reg bus_enable;
	reg bus_wr_en;
	reg [31:0] bus_addr;
	reg [31:0] bus_i_data;
	reg [3:0] bus_be;
	wire [31:0] bus_o_data;
	wire bus_ready;
	wire bus_irq;
	wire bus_err;
	wire bus_tx_pin;
	reg [15:0] test_phase;
	
	wire sck_pin;
	wire cs_pin;
	wire [3:0] sio_en;
	wire [3:0] sio_dout;
	reg [3:0] sio_din;

	localparam
		DATA_WIDTH=32,
		SRAM_ADDR_WIDTH=16;

	spi_sram_mem #(
		.ADDR_WIDTH(32), .DATA_WIDTH(32),
		
		.CLK_FREQ_MHZ(50),
		.SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH), .DUMMY_BYTES(6), .CMD_READ(8'h03),
		.CMD_WRITE(8'h02), .CMD_EQIO(8'h38), .MIN_CPH_NS(50),
		.SPI_TIMER_BITS(4), .QPI_TIMER_BITS(2),
		.MIN_WAKEUP_NS(150000), .PSRAM_RESET(1), .CMD_RESETEN(8'h66), .CMD_RESET(8'h99)
	) sram (
		.clk(clk), .rst_n(rst_n),
		.enable(bus_enable),
		.wr_en(bus_wr_en),
		.addr(bus_addr),
		.i_data(bus_i_data),
		.be(bus_be),
		.ready(bus_ready),
		.o_data(bus_o_data),
		.irq(bus_irq),
		.bus_err(bus_err),
		.sio_din(sio_din), .sio_dout(sio_dout), .sio_en(sio_en),
		.cs_pin(cs_pin),
		.sck_pin(sck_pin)
	);

    // Parameters
    localparam CLK_PERIOD = 50;    // 20MHz
	
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Test Logic ---
    integer i;
    integer j;
    
    initial begin
        // Waveform setup
        $dumpfile("spi_sram_mem.vcd");
        $dumpvars(0, spi_sram_mem_tb);

        // Initialize
        clk = 0;
        rst_n = 0;
        bus_enable = 0;
        bus_wr_en = 0;
        bus_addr = 0;
        bus_i_data = 0;
        bus_be = 0;
        test_phase = 0;
        i = 0;
        j = 0;

        // Reset system
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);

		test_phase = 1;
		// write 32-bits to offset 0x10
		write_bus(32'h0010, 32'h11223344, 4'b1111, 0);
		test_phase = 2;
		// read 32-bits back
		read_bus(32'h0010, 4'b1111, 0, 32'h11223344);

		test_phase = 3;
        // read 16-bits
        read_bus(32'h0010, 4'b0011, 0, {16'b0, 16'h3344});
        test_phase = 4;
        read_bus(32'h0012, 4'b0011, 0, {16'b0, 16'h1122});
        test_phase = 5;
        // read 8-bits
        read_bus(32'h0010, 4'b0001, 0, {24'b0, 8'h44});
        read_bus(32'h0011, 4'b0001, 0, {24'b0, 8'h33});
        read_bus(32'h0012, 4'b0001, 0, {24'b0, 8'h22});
        read_bus(32'h0013, 4'b0001, 0, {24'b0, 8'h11});
        test_phase = 6;
        // 16-bit write
        write_bus(32'h20, 32'h00005566, 4'b0011, 0);
        // read back
		read_bus(32'h20, 4'b0011, 0, 32'h00005566);
        // 8-bit write
        write_bus(32'h30, 32'h77, 4'b0001, 0);
        write_bus(32'h31, 32'h88, 4'b0001, 0);
        write_bus(32'h32, 32'h99, 4'b0001, 0);
        write_bus(32'h33, 32'hAA, 4'b0001, 0);
        // read back
		read_bus(32'h0030, 4'b1111, 0, 32'hAA998877);

		// fill memory with predictable data
		test_phase = 7;
		for (i = 0; i < 1024; i++) begin
			write_bus({22'b0, i[9:0]}, {24'b0, i[8:1] + i[7:0]}, 4'b0001, 0); // write (255 - x) & 255 to mem[x=0..1023]
		end
		
		// now randomly read
		test_phase = 8;
		for (i = 0; i < 1024; i++) begin
			j = $urandom_range(0, 1023);
			read_bus({22'b0, j[9:0]}, 4'b0001, 0, {24'b0, j[8:1] + j[7:0]});
		end
		
        repeat(16) @(posedge clk);
        $finish;
	end

	task check_irq(input expected);
		begin
			if (bus_irq !== expected) begin
				$display("ASSERTION FAILED:  bus_irq should be %d right now.", expected);
				repeat(16) @(posedge clk);
				$fatal;
			end
		end
	endtask
		
    task write_bus(input [31:0] address, input [31:0] data, input [3:0] be, input bus_err_expected);
        begin
			@(posedge clk); #1;
            bus_wr_en  = 1;
            bus_addr   = address;
            bus_be     = be;
            bus_i_data = data;
            bus_enable = 1;
            @(posedge clk); #1;
            wait(bus_ready == 1); #1;
            if (!bus_err_expected && bus_err !== 0) begin
                $display("ASSERTION ERROR: Unexpected bus_err at %h", address);
                $fatal;
            end
            bus_enable = 0;
            bus_wr_en  = 0;
            @(posedge clk); #1;
        end
    endtask

    task read_bus(input [31:0] address, input [3:0] be, input bus_err_expected, input [31:0] expected);
        begin
			@(posedge clk); #1;
            bus_wr_en  = 0;
            bus_addr   = address;
            bus_be     = be;
            bus_enable = 1;
            @(posedge clk); #1;
            wait(bus_ready == 1); #1

            // Now that the loop exited, ready is high.
            // Because o_data is registered, the data is stable on THIS edge.
            if (!bus_err_expected && bus_err !== 0) begin
                $display("ASSERTION ERROR: Unexpected bus_err at %h", address);
                $fatal;
            end

            if (!bus_err_expected && bus_o_data !== expected) begin
                $display("ASSERTION ERROR: Data mismatch bus=%h vs exp=%h @ %h", bus_o_data, expected, address);
                repeat(16) @(posedge clk);
                $fatal;
            end
            bus_enable = 0;
            @(posedge clk); #1;
        end
    endtask
 endmodule
