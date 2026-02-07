`timescale 1ns/1ps

module sp_bram_tb();

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
	reg [7:0] test_phase;

	sp_bram #(.WIDTH(8192), .ADDR_WIDTH(32), .DATA_WIDTH(32))
	sp_bram_dut(.clk(clk), .rst_n(rst_n), 
		.enable(bus_enable), .wr_en(bus_wr_en), 
		.addr(bus_addr), .i_data(bus_i_data), .be(bus_be), 
		.ready(bus_ready), .o_data(bus_o_data), .irq(bus_irq), .bus_err(bus_err));

    // Parameters
    localparam CLK_PERIOD = 20;    // 50MHz
	
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Test Logic ---
    integer i;
    integer j;
    
    initial begin
        // Waveform setup
        $dumpfile("sp_bram.vcd");
        $dumpvars(0, sp_bram_tb);

        // Initialize
        clk = 0;
        rst_n = 0;
        bus_enable = 0;
        bus_wr_en = 0;
        bus_addr = 0;
        bus_i_data = 0;
        bus_be = 0;
        test_phase = 0;

        // Reset system
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);

		// try some invalid ops
		$display("Trying some invalid unaligned stuff...");
			write_bus(32'h1, 0, 4'b1111, 1); // expect a bus error writing 32-bits to 1 mod 4
			write_bus(32'h2, 0, 4'b1111, 1); // expect a bus error writing 32-bits to 2 mod 4
			write_bus(32'h3, 0, 4'b1111, 1); // expect a bus error writing 32-bits to 3 mod 4
			write_bus(32'h1, 0, 4'b0011, 1); // expect a bus error writing 16-bits to 1 mod 2
		$display("PASSED.");
		test_phase = 1;
		
		// write 32-bits to offset 0x10
		write_bus(32'h0010, 32'h11223344, 4'b1111, 0);
		test_phase = 3;
		// read 32-bits back
		read_bus(32'h0010, 4'b1111, 0, 32'h11223344);
		test_phase = 4;
        // read 16-bits
        read_bus(32'h0010, 4'b0011, 0, {16'b0, 16'h3344});
        test_phase = 5;
        read_bus(32'h0012, 4'b0011, 0, {16'b0, 16'h1122});
        test_phase = 6;
        // read 8-bits
        read_bus(32'h0010, 4'b0001, 0, {24'b0, 16'h44});
        read_bus(32'h0011, 4'b0001, 0, {24'b0, 16'h33});
        read_bus(32'h0012, 4'b0001, 0, {24'b0, 16'h22});
        read_bus(32'h0013, 4'b0001, 0, {24'b0, 16'h11});
        test_phase = 7;
        // 16-bit write
        write_bus(32'h20, 32'h5566, 4'b0011, 0);
        // read back
		read_bus(32'h20, 4'b1111, 0, 32'h00005566);
        // 8-bit write
        write_bus(32'h30, 32'h77, 4'b0001, 0);
        write_bus(32'h31, 32'h88, 4'b0001, 0);
        write_bus(32'h32, 32'h99, 4'b0001, 0);
        write_bus(32'h33, 32'hAA, 4'b0001, 0);
        // read back
		read_bus(32'h0030, 4'b1111, 0, 32'hAA998877);
		
		// fill memory with predictable data
		test_phase = 8;
		for (i = 0; i < 1024; i++) begin
			write_bus({22'b0, i[9:0]}, {24'b0, 8'd255 - i[7:0]}, 4'b0001, 0); // write (255 - x) & 255 to mem[x=0..1023]
		end
		
		// now randomly read
		test_phase = 9;
		for (i = 0; i < 1024; i++) begin
			j = $urandom_range(0, 1023);
			read_bus({22'b0, j[9:0]}, 4'b0001, 0, {24'b0, 8'd255 - j[7:0]});
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
			if (bus_err !== 0) begin
				$display("ASSERTION ERROR: bus_err is not 0 in write_bus()");
				repeat(16) @(posedge clk);
				$fatal;
			end
			bus_wr_en = 1;
			bus_addr = address;
			bus_be = be;
			bus_i_data = data;
			bus_enable = 1;
			wait(bus_ready == 1);
			if (!bus_ready) begin
				$display("bus should be ready one cycle after reading.");
				test_phase = 255;
				repeat(16) @(posedge clk);
				$fatal;
			end
			if (!bus_err_expected && bus_err !== 0) begin
				$display("ASSERTION ERROR: bus_err is not 0 in write_bus()");
				repeat(16) @(posedge clk);
				$fatal;
			end
			bus_be = 0;
			bus_wr_en = 0;
			bus_enable = 0;
			wait(bus_ready == 0);
		end
	endtask
	
    task read_bus(input [31:0] address, input [3:0] be, input bus_err_expected, input [31:0] expected);
		begin
			if (bus_err !== 0) begin
				$display("ASSERTION ERROR: bus_err is not 0 in read_bus()");
				$fatal;
			end
			bus_wr_en = 0;
			bus_addr = address;
			bus_be = be;
			bus_enable = 1;
			wait(bus_ready == 1);
			if (!bus_ready) begin
				$display("bus should be ready one cycle after reading.");
				test_phase = 255;
				repeat(16) @(posedge clk);
				$fatal;
			end
			if (!bus_err_expected && bus_err !== 0) begin
				$display("ASSERTION ERROR: bus_err is not 0 in read_bus()");
				repeat(16) @(posedge clk);
				$fatal;
			end
			if (bus_o_data !== expected) begin
				$display("ASSERTION ERROR: Invalid data read back bus=%h vs exp=%h @ %h", bus_o_data, expected, address);
				repeat(16) @(posedge clk);
				$fatal;
			end
			bus_enable = 0;
			wait(bus_ready == 0);
		end
	endtask
endmodule
