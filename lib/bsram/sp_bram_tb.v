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
	reg [15:0] test_phase;

	sp_bram #(.WIDTH(8192), .ADDR_WIDTH(32), .DATA_WIDTH(32))
	sp_bram_dut(.clk(clk), .rst_n(rst_n), 
		.enable(bus_enable), .wr_en(bus_wr_en),
		.addr(bus_addr), .i_data(bus_i_data), .be(bus_be), 
		.ready(bus_ready), .o_data(bus_o_data), .irq(bus_irq), .bus_err(bus_err));

    // Parameters
    localparam CLK_PERIOD = 50;    // 20MHz
	
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
        i = 0;
        j = 0;

        // Reset system
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);

//`define QUICK
`ifdef QUICK
// --- PHASE 1: Write 32-bits ---
        // We write 0x11223344 to address 0x10
        @(posedge clk);
        test_phase = 1;
        bus_addr   <= 32'h0070;
        bus_i_data <= 32'h11223344;
        bus_be     <= 4'b1111;
        bus_wr_en  <= 1;
        bus_enable <= 1;
        
        @(posedge clk);
        // Note: addr_off is now 4. If we keep enable high, it writes again to 0x14!
        bus_enable <= 0; 
        bus_wr_en  <= 0;

        // --- PHASE 2: Read 32-bits ---
        // Verify what we just wrote
        @(posedge clk);
        test_phase = 2;
        bus_addr   <= 32'h0070;
        bus_be     <= 4'b1111;
        bus_enable <= 1;
        
        @(posedge clk); // Cycle 1: BRAM processes addr 0x10
        @(posedge clk); // Cycle 2: o_data captures o_mem_mapped
        $display("32-bit read: %h", bus_o_data);
        bus_enable <= 0;
        @(posedge clk);

        // --- PHASE 3: Burst Read 8-bits (Streaming) ---
        // Because your module increments addr_off automatically, 
        // we just hold enable high to sweep through bytes.
        @(posedge clk);
        test_phase = 3;
        bus_addr   <= 32'h0070; // Base address
        bus_be     <= 4'b0001;  // Byte mode
        bus_enable <= 1;        // addr_off starts at 0
        @(posedge clk); // Cycle 1: BRAM processes addr 0x10

        // We stay enabled for 4 cycles to read 4 bytes sequentially
        repeat(4) begin
			@(posedge clk); 
			$display("8-bit read: %h", bus_o_data);
		end
        bus_enable <= 0;
        @(posedge clk);

        // --- PHASE 3: Burst Read 16-bits (Streaming) ---
        // Because your module increments addr_off automatically, 
        // we just hold enable high to sweep through bytes.
        @(posedge clk);
        test_phase = 4;
        bus_addr   <= 32'h0070; // Base address
        bus_be     <= 4'b0011;  // word mode
        bus_enable <= 1;        // addr_off starts at 0
        @(posedge clk); // Cycle 1: BRAM processes addr 0x10

        // We stay enabled for 2 cycles to read 4 bytes sequentially
        repeat(2) begin
			@(posedge clk); 
			$display("16-bit read: %h", bus_o_data);
		end
        bus_enable <= 0;
        @(posedge clk);
        
        // phase 4: stream 4 bytes out 
        @(posedge clk);
        test_phase = 5;
        bus_addr <= 32'h0080;
        bus_be <= 4'b0001;
        bus_wr_en <= 1;
        bus_enable <= 1;
        bus_i_data <= 32'hF0;
        @(posedge clk);
        bus_i_data <= 32'hF1;
        @(posedge clk);
        bus_i_data <= 32'hF2;
        @(posedge clk);
        bus_i_data <= 32'hF3;
        @(posedge clk);
        bus_enable <= 0;
        bus_wr_en <= 0; // <---- missing write disable
        @(posedge clk);
        
        // --- PHASE 5: Burst Read 8-bits (Streaming) ---
        // Because your module increments addr_off automatically, 
        // we just hold enable high to sweep through bytes.
        @(posedge clk);
        test_phase = 6;
        bus_addr   <= 32'h0080; // Base address
        bus_be     <= 4'b0001;  // Byte mode
        bus_enable <= 1;        // addr_off starts at 0
        @(posedge clk); // Cycle 1: BRAM processes addr 0x10

        // We stay enabled for 4 cycles to read 4 bytes sequentially
        repeat(4) begin
			@(posedge clk); 
			$display("8-bit read: %h", bus_o_data);
		end
        bus_enable <= 0;
        @(posedge clk);
        

        repeat(16) @(posedge clk);
		
		$fatal;
`endif

		// try some invalid ops
		test_phase = 1;
		$display("Trying some invalid unaligned stuff...");
			write_bus(32'h1, 0, 4'b1111, 1); // expect a bus error writing 32-bits to 1 mod 4
			write_bus(32'h2, 0, 4'b1111, 1); // expect a bus error writing 32-bits to 2 mod 4
			write_bus(32'h3, 0, 4'b1111, 1); // expect a bus error writing 32-bits to 3 mod 4
			write_bus(32'h1, 0, 4'b0011, 1); // expect a bus error writing 16-bits to 1 mod 2
		$display("PASSED.");

		test_phase = 2;
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
        write_bus(32'h20, 32'h00005566, 4'b1111, 0);
        // read back
		read_bus(32'h20, 4'b1111, 0, 32'h00005566);
        // 8-bit write
        write_bus(32'h30, 32'h77, 4'b0001, 0);
        write_bus(32'h31, 32'h88, 4'b0001, 0);
        write_bus(32'h32, 32'h99, 4'b0001, 0);
        write_bus(32'h33, 32'hAA, 4'b0001, 0);
        // read back
		read_bus(32'h0030, 4'b1111, 0, 32'hAA998877);
		// test burst read
		test_phase = 8;
		read_bus_burst4bytes(32'h0010, 0, 32'h11223344);
		read_bus_burst4bytes(32'h0020, 0, 32'h00005566);
		// test burst write
		test_phase = 9;
		write_bus_burst4bytes(32'h0040, 0, 32'h55667788);
		test_phase = 9 + 256;
		read_bus(32'h0040, 4'b1111, 0, 32'h55667788);

		// fill memory with predictable data
		test_phase = 10;
		for (i = 0; i < 1024; i++) begin
			write_bus({22'b0, i[9:0]}, {24'b0, 8'd255 - i[7:0]}, 4'b0001, 0); // write (255 - x) & 255 to mem[x=0..1023]
		end
		
		// now randomly read
		test_phase = 11;
		for (i = 0; i < 1024; i++) begin
			j = $urandom_range(0, 1023);
			read_bus({22'b0, j[9:0]}, 4'b0001, 0, {24'b0, 8'd255 - j[7:0]});
		end
		
		// write repeated bursts then read back singly
		test_phase = 12;
		for (i = 0; i < 256; i += 4) begin
			write_bus_burst4bytes(32'h0060 + i[31:0], 0, 32'h98765432);
		end
		test_phase = 13;
		for (i = 0; i < 256; i += 4) begin
			read_bus(32'h0060 + i[31:0], 4'b1111, 0, 32'h98765432);
		end		
		test_phase = 14;
		for (i = 0; i < 256; i += 4) begin
			read_bus_burst4bytes(32'h0060 + i[31:0], 0, 32'h98765432);
		end

		test_phase = 15;
		for (i = 0; i < 256; i += 16) begin
			write_bus_burst4dwords(32'h0060 + i[31:0], 0, 128'h98765432_12345678_FF00FF00_00AA00AA);
		end
		test_phase = 16;
		for (i = 0; i < 256; i += 16) begin
			read_bus_burst4dwords(32'h0060 + i[31:0], 0, 128'h98765432_12345678_FF00FF00_00AA00AA);
		end
		test_phase = 17;
		for (i = 4; i < 240; i += 16) begin
			read_bus_burst4dwords(32'h0060 + i[31:0], 0, 128'h00AA00AA_98765432_12345678_FF00FF00);
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
            bus_wr_en  <= 1;
            bus_addr   <= address;
            bus_be     <= be;
            bus_i_data <= data;
            bus_enable <= 1;
            
            // Wait for ready or error
            @(posedge clk); // Give the RTL at least one cycle to react
            @(posedge clk); // 
			if (bus_ready !== 1) begin
				$display("ASSERTION ERROR: bus_ready should be 1 after write call in write_bus");
				repeat(16) @(posedge clk);
				$fatal;
			end
            
            if (!bus_err_expected && bus_err !== 0) begin
                $display("ASSERTION ERROR: Unexpected bus_err at %h", address);
                $fatal;
            end
            bus_enable <= 0;
            bus_wr_en  <= 0;
            @(posedge clk);
        end
    endtask

    task read_bus(input [31:0] address, input [3:0] be, input bus_err_expected, input [31:0] expected);
        begin
            bus_wr_en  <= 0;
            bus_addr   <= address;
            bus_be     <= be;
            bus_enable <= 1;

            // Wait until ready is high
            @(posedge clk); // process address
            @(posedge clk); // read data
			if (bus_ready !== 1) begin
				$display("ASSERTION ERROR: bus_ready should be 1 after read call in read_bus");
				repeat(16) @(posedge clk);
				$fatal;
			end

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
            bus_enable <= 0;
            @(posedge clk);
        end
    endtask
    
	task read_bus_burst4bytes(input [31:0] address, input bus_err_expected, input [31:0] expected);
        integer x;
        begin
            bus_wr_en  <= 0;
            bus_addr   <= address;
            bus_be     <= 4'b0001;
            bus_enable <= 1;
            @(posedge clk); // process address
            @(posedge clk); // first word
			if (bus_ready !== 1) begin
				$display("ASSERTION ERROR: bus_ready should be 1 after read call in read_bus_burst4bytes");
				repeat(16) @(posedge clk);
				$fatal;
			end

            for (x = 0; x < 4; x++) begin
                if (bus_o_data[7:0] !== expected[7:0]) begin
                    $display("BURST ERROR: bus=%h vs exp=%h @ %h step %d", bus_o_data[7:0], expected[7:0], address, x);
                    $fatal;
                end
                expected = {8'b0, expected[31:8]};
                @(posedge clk); 
            end
            bus_enable <= 0;
            @(posedge clk);
        end
    endtask


	task read_bus_burst4dwords(input [31:0] address, input bus_err_expected, input [127:0] expected);
		integer x;
		begin
			if (bus_err !== 0) begin
				$display("ASSERTION ERROR: bus_err is not 0 in read_bus()");
				$fatal;
			end
			bus_wr_en <= 0;
			bus_addr <= address;
			bus_be <= 4'b1111;
			bus_enable <= 1;
			@(posedge clk); // process address
			@(posedge clk); // read data
			if (bus_ready !== 1) begin
				$display("ASSERTION ERROR: bus_ready should be 1 after read call in read_bus_burst4dwords");
				repeat(16) @(posedge clk);
				$fatal;
			end

			for (x = 0; x < 4; x++) begin
				if (bus_o_data[31:0] !== expected[31:0]) begin
					$display("ASSERTION ERROR: Invalid data read back bus=%h vs exp=%h @ %h step %d", bus_o_data[31:0], expected[31:0], address, x);
					repeat(16) @(posedge clk);
					$fatal;
				end
				expected = {32'b0, expected[127:32]};
				@(posedge clk);
			end
			bus_enable <= 0;
			@(posedge clk);
		end
	endtask

    task write_bus_burst4bytes(input [31:0] address, input bus_err_expected, input [31:0] data);
		integer x;
		begin
			if (bus_err !== 0) begin
				$display("ASSERTION ERROR: bus_err is not 0 in read_bus()");
				$fatal;
			end
			bus_wr_en <= 1;
			bus_addr <= address;
			bus_be <= 4'b0001;
			bus_enable <= 1;
			bus_i_data <= data[7:0];
			@(posedge clk);
			x = 0;
			for (x = 0; x < 3; x++) begin
				data = {8'b0, data[31:8]};
				bus_i_data <= data[7:0];
				@(posedge clk);
			end
			bus_enable <= 0;
			bus_wr_en <= 0;
			@(posedge clk);
		end
	endtask

    task write_bus_burst4dwords(input [31:0] address, input bus_err_expected, input [127:0] data);
		integer x;
		begin
			if (bus_err !== 0) begin
				$display("ASSERTION ERROR: bus_err is not 0 in read_bus()");
				$fatal;
			end
			bus_wr_en <= 1;
			bus_addr <= address;
			bus_be <= 4'b1111;
			bus_enable <= 1;
			bus_i_data <= data[31:0];
			@(posedge clk);
			x = 0;
			for (x = 0; x < 3; x++) begin
				data = {32'b0, data[127:32]};
				bus_i_data <= data[31:0];
				@(posedge clk);
			end
			bus_enable <= 0;
			bus_wr_en <= 0;
			@(posedge clk);
		end
	endtask
endmodule
