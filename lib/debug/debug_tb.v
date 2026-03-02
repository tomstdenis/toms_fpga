`timescale 1ns/1ps

module debug_tb();
	localparam
		READ_CMD_IDENT = 0;

	reg clk;
	reg rst_n;
	reg [7:0] prescaler;
	
	reg rx_data;
	reg rx_clk;
	
	wire tx_data;
	wire tx_clk;
	reg tx_clk_prev;
	reg [127:0] debug_outgoing_data;
	wire debug_incoming_tgl;
	reg  prev_debug_incoming_tgl;
	wire [127:0] debug_incoming_data;
	reg [127:0] identity;
	
	serial_debug #(.BITS(128)) debug_dut(
		.clk(clk), .rst_n(rst_n),
		.prescaler(prescaler), .rx_data(rx_data), .rx_clk(rx_clk),
		.tx_data(tx_data), .tx_clk(tx_clk),
		.debug_outgoing_data(debug_outgoing_data),
		.debug_incoming_data(debug_incoming_data),
		.debug_incoming_tgl(debug_incoming_tgl),
		.identity(identity)
	);

    // Parameters
    localparam CLK_PERIOD = 20;    //  50MHz
	
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Test Logic ---
    localparam
		SF_BITS = 128 + 16;
    integer i;
    integer test_phase;
	reg [SF_BITS-1:0] sf_buf;

	initial begin
        // Waveform setup
        $dumpfile("debug.vcd");
        $dumpvars(0, debug_tb);
        
        clk = 0;
        rst_n = 0;
        prescaler = 2;
        rx_data = 0;
        rx_clk = 1;
        tx_clk_prev = 1;
        prev_debug_incoming_tgl = 0;
        identity = 128'h12345678_11223344_55667788_99AABBCC;
        debug_outgoing_data = 128'hFEDCBA98_76543210_00112233_44556677;
        test_phase = 0;
        i = 0;
        sf_buf = 0;

        // Reset system
        repeat(10) @(posedge clk);
        rst_n = 1;
		@(posedge clk);

		// send enumeration
		test_phase = 0;
		sf_buf = 0;
		sf_buf[15:1] = 15'h7FFF;					// broadcast packet
		sf_buf[30:16] = 15'h1234;							// first address (pick something non zero)
		transmit_sfbuf(sf_buf);
		
		// read back enumeration
		test_phase = 1;
		sf_buf[30:16] = 15'h1235;							// we expect an enumeration of 1 back
		receive_sfbuf(sf_buf);

		// probe identity
		test_phase = 2;
		sf_buf[15:1]  = 15'h1234;
		sf_buf[0]	  = 0;							// READ
		sf_buf[23:16] = READ_CMD_IDENT;				// read identity
		transmit_sfbuf(sf_buf);
		
		// check feedback
		test_phase = 3;
		sf_buf[SF_BITS-1:16] = identity;
		receive_sfbuf(sf_buf);
		
		// ask identity of non-existent node should just pass through
		test_phase = 4;
		sf_buf[15:1]  = 15'h1235;
		sf_buf[0]	  = 0;							// READ
		sf_buf[23:16] = READ_CMD_IDENT;				// read identity
		transmit_sfbuf(sf_buf);
		test_phase = 5;
		receive_sfbuf(sf_buf);
		
		// read node
		test_phase = 6;
		sf_buf[15:1]  = 15'h1234;
		sf_buf[0]	  = 0;							// READ
		sf_buf[23:16] = 8'hFF;						// read node
		transmit_sfbuf(sf_buf);
		
		// check feedback
		test_phase = 7;
		sf_buf[SF_BITS-1:16] = debug_outgoing_data;
		receive_sfbuf(sf_buf);

		// read node that doesn't exist
		test_phase = 8;
		sf_buf[15:1]  = 15'h1233;
		sf_buf[0]	  = 0;							// READ
		sf_buf[23:16] = 8'hFF;						// read node
		transmit_sfbuf(sf_buf);
		test_phase = 9;
		receive_sfbuf(sf_buf);
		
		// write to node
		test_phase = 10;
		sf_buf[15:1]  = 15'h1234;
		sf_buf[0]	  = 1;							// WRITE
		sf_buf[SF_BITS-1:16] = 128'hAABBCCDD_EEFF0011_22334455_66778899;
		transmit_sfbuf(sf_buf);
		test_phase = 11;
		receive_sfbuf(sf_buf);						// writes should pass through
		
		// expect incoming data to change
		test_phase = 12;
		wait (debug_incoming_tgl != prev_debug_incoming_tgl);
		prev_debug_incoming_tgl = debug_incoming_tgl;
		if (debug_incoming_data != sf_buf[SF_BITS-1:16]) begin
			for (i = 0; i < 128; i++) begin
				if (sf_buf[16+i] != debug_incoming_data[i]) begin
					$display("Bit %d of written data doesn't match expected (%d)", i, sf_buf[16+i]);
					$fatal;
				end
			end
		end

		$finish;
	end
	
	task transmit_sfbuf(input [SF_BITS-1:0] bits);
		integer x;
		begin
			for (x = 0; x < SF_BITS; x++) begin
				rx_clk = 1'b0;
				rx_data = bits[SF_BITS-1];
				bits = {bits[SF_BITS-2:0], 1'b0};
				@(posedge clk);
				@(posedge clk); #1;
				rx_clk = 1'b1;
				@(posedge clk);
				@(posedge clk); #1;
			end
		end
	endtask
	
	task receive_sfbuf(input [SF_BITS-1:0] ebits);
		integer x;
		reg [SF_BITS-1:0] bits;
		begin
			x = 0;
			bits = 0;
			while (x < (SF_BITS)) begin
				@(posedge clk);
				tx_clk_prev = tx_clk;
				@(posedge clk); #1;
				if (tx_clk_prev == 1 && tx_clk == 0) begin
					bits = {bits[SF_BITS-2:0], tx_data};
					x = x + 1;
				end
			end
			if (bits != ebits) begin
				$display("Expected SFBUF mismatch");
				for (x = 0; x < SF_BITS; x++) begin
					if (ebits[x] != bits[x]) begin
						$display("\t Bit %d differs (expected %d)", x, ebits[x]);
					end
				end
				$fatal;
			end
			@(posedge clk); #1;
		end
	endtask
endmodule
