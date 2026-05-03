`timescale 1ns/1ps

module spidma_tb();
	localparam
		DUMMY = 6,
		HOST_MEM_ADDR = 11,
		SRAM_ADDR_WIDTH = 24;

	reg [4:0] test_phase;
	reg clk;
	reg rst_n;
	
	wire ready;
	wire [HOST_MEM_ADDR-1:0] host_mem_addr;
	wire host_mem_wr_en;
	wire [7:0] host_mem_data_in;
	reg  [7:0] host_mem_data_out;
	reg  [7:0] host_memory[0:2047];
	reg  [7:0] shadow_memory[0:2047];
	reg [11:0] test_target_address;
	
	always @(posedge clk) begin
		if (rst_n) begin
			host_mem_data_out <= host_memory[host_mem_addr];
			if (host_mem_wr_en) begin
				host_memory[host_mem_addr] <= host_mem_data_in;
			end
		end
	end
	
	reg [3:0] cmd_value;
	reg cmd_valid;
	reg [SRAM_ADDR_WIDTH-1:0] cmd_spi_address;
	reg [HOST_MEM_ADDR-1:0] cmd_host_address;
	reg [7:0] cmd_burst_len;
		
	wire sck_pin;
	wire cs_pin;
	wire [3:0] sio_en;
	wire [3:0] sio_dout;
	reg [3:0] sio_din;
	
	spidma #(
		.CLK_FREQ_MHZ(50), 
		.SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH), .DUMMY_CYCLES(DUMMY), .HOST_MEM_ADDR(HOST_MEM_ADDR),
		.CMD_READ(8'hEB),
		.CMD_WRITE(8'h38), .CMD_EQIO(8'h35), .MIN_CPH_NS(50),
		.SPI_TIMER_BITS(2), .QPI_TIMER_BITS(0),
		.MIN_WAKEUP_NS(150000), .CMD_RESETEN(8'h66), .CMD_RESET(8'h99)) spud(
			.clk(clk), .rst_n(rst_n),

			.ready(ready),
			.host_mem_addr(host_mem_addr), .host_mem_wr_en(host_mem_wr_en),
			.host_mem_data_in(host_mem_data_in), .host_mem_data_out(host_mem_data_out),
			.cmd_value(cmd_value), .cmd_valid(cmd_valid), .cmd_spi_address(cmd_spi_address),
			.cmd_host_address(cmd_host_address), .cmd_burst_len(cmd_burst_len),

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
        $dumpfile("spidma.vcd");
        $dumpvars(0, spidma_tb);

		for (X = 0; X < 2048; X = X + 1) begin
			host_memory[X] = 0;
			shadow_memory[X] = 0;
		end
		X = 0;
		i = 0;
		j = 0;
		k = 0;
		rst_n = 0;
		clk   = 0;
		host_mem_data_out = 0;
		cmd_value = 0;
		cmd_valid = 0;
		cmd_spi_address = 0;
		cmd_host_address = 0;
		cmd_burst_len = 0;
		sio_din = 4'b0000;

        // Reset system
        repeat(10) @(posedge clk);
        rst_n = 1;
        
        // fill first 16 bytes with something predictable
        test_phase = 1;
        for (X = 0; X < 16; X = X + 1) begin
			host_memory[X] = X[7:0] + 1'b1;
			shadow_memory[X] = X[7:0] + 1'b1;
		end
		
		// issue reset
		cmd_value = `spidma_reset;
		cmd_valid = 1;
		wait(ready == 1);
		cmd_valid = 0;
		wait(ready == 0);
		
		// issue EQIO
		cmd_value = `spidma_eqio;
		cmd_valid = 1;
		wait(ready == 1);
		cmd_valid = 0;
		wait(ready == 0);
		
		
		// write host mem [0..3] to spi[0x10..0x13]
		cmd_value = `spidma_cmd_write;
		cmd_host_address = 0;
		cmd_spi_address = 16;
		cmd_burst_len = 3; // burst_len == size - 1
		cmd_valid = 1;
		wait(ready == 1);
		cmd_valid = 0;
		wait(ready == 0);
		
		// read spi[0x10..0x13] to host mem[0x100..0x103]
		test_phase = 2;
		cmd_value = `spidma_cmd_read;
		cmd_host_address = 'h100;
		cmd_spi_address = 'h10;
		cmd_burst_len = 3;
		cmd_valid = 1;
		wait(ready == 1);
		cmd_valid = 0;
		wait(ready == 0);
		
		for (X = 0; X < 4; X = X + 1) begin
			if (host_memory['h100 + X] != host_memory[X] || host_memory['h100 + X] != (X[7:0] + 1'b1)) begin
				$display("Read at %d failed, %x %x", X, host_memory[X], host_memory['h100 + X]);
				$fatal;
			end
		end
/* verilator lint_off WIDTHTRUNC */		
		// randomize memory
		for (X = 0; X < 2048; X = X + 1) begin
			host_memory[X] = $urandom_range(0,255);
			shadow_memory[X] = host_memory[X];
		end
		
		// let's do random tests
		for (X = 0; X < 1000; X = X + 1) begin
			// pick settings 
			cmd_host_address = $urandom_range(0,2047);
			test_target_address = $urandom_range(0,2047);
			cmd_spi_address  = $urandom_range(0,4095);
			cmd_burst_len    = $urandom_range(0,255);
			$display("Test %d: host=%x target=%x spi=%x burst=%d", X, cmd_host_address, test_target_address, cmd_spi_address, cmd_burst_len);
			
			// shadow the transfer
			for (i = 0; i <= cmd_burst_len; i = i + 1) begin
				shadow_memory[(test_target_address + i[11:0]) % 2048] = host_memory[(cmd_host_address + i[11:0]) % 2048]; // use host memory so we can deal with overlaps
			end
			
			// issue the transfer to spi
			cmd_value = `spidma_cmd_write;
			cmd_valid = 1;
			wait(ready == 1);
			cmd_valid = 0;
			wait(ready == 0);
			
			// issue transfer to host mem
			cmd_host_address = test_target_address;
			cmd_value = `spidma_cmd_read;
			cmd_valid = 1;
			wait(ready == 1);
			cmd_valid = 0;
			wait(ready == 0);
			
			for (i = 0; i < 2048; i = i + 1) begin
				if (shadow_memory[i[11:0]] != host_memory[i[11:0]]) begin
					$display("Byte difference at address %x", i);
					$fatal;
				end
			end
		end

        repeat(10) @(posedge clk);
        $finish;
	end

endmodule
