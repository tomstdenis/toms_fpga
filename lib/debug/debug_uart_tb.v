`timescale 1ns/1ps

module debug_uart_tb();
	localparam
		READ_CMD_IDENT = 0;

	reg clk;
	reg rst_n;
	reg [7:0] prescaler;
	
	/* The debug node itself */
	wire node_rx_data;
	wire node_rx_clk;
	wire node_tx_data;
	wire node_tx_clk;
	reg [127:0] node_debug_outgoing_data;
	wire node_debug_incoming_tgl;
	reg  prev_debug_incoming_tgl;
	wire [127:0] node_debug_incoming_data;
	reg [127:0] node_identity;
	
	serial_debug #(.BITS(128)) debug_node(
		.clk(clk), .rst_n(rst_n),
		.prescaler(prescaler), .rx_data(node_rx_data), .rx_clk(node_rx_clk),
		.tx_data(node_tx_data), .tx_clk(node_tx_clk),
		.debug_outgoing_data(node_debug_outgoing_data),
		.debug_incoming_data(node_debug_incoming_data),
		.debug_incoming_tgl(node_debug_incoming_tgl),
		.identity(node_identity)
	);
	
	/* UART module attached to the debug node 
	 *
	 * This would sit inside your design and it's what the host talks to over UART
	 */
	wire [15:0] baud_div = 16'd9;					// ludicrously fast UART but more importantly not equal to our SPI clock prescaler
	wire uart_debug_rx_pin;							// these are relative to the controller
	wire uart_debug_tx_pin;							// the host UART transmits to the rx_pin and receives from the tx_pin, etc...
	
	serial_debug_uart #(.BITS(128)) uart_debug(
		.clk(clk), .rst_n(rst_n),
		.prescaler(prescaler),
		
		// connect to node
		.debug_tx_data(node_tx_data),				// this is connected to our one debug node.  In practice
		.debug_tx_clk(node_tx_clk),					// tx_* is connected to the last nodes tx
		.debug_rx_data(node_rx_data),				// and rx is connected to the first nodes RX
		.debug_rx_clk(node_rx_clk),
		
		// connect uart
		.uart_bauddiv(baud_div),
		.uart_rx_pin(uart_debug_rx_pin),			// these are the wires for the debugger's UART
		.uart_tx_pin(uart_debug_tx_pin)				// they would be crossed to talk with a the host (see below)
	);

	/* "host" is the UART that the PC controls
		The host is wired with TX/RX swapped to the debug_uart.
		
		In a system "host" might represent a USB to serial device, etc.
	*/ 
	reg host_uart_tx_start;
	reg [7:0] host_uart_tx_data_in;
	wire host_uart_tx_fifo_full;
	reg host_uart_rx_read;
	wire host_uart_rx_ready;
	wire [7:0] host_uart_rx_byte;
	
	uart #(.FIFO_DEPTH(32), .RX_ENABLE(1), .TX_ENABLE(1)) host_uart(
		.clk(clk), .rst_n(rst_n),
		.baud_div(baud_div),
		.uart_tx_start(host_uart_tx_start),
		.uart_tx_data_in(host_uart_tx_data_in),
		.uart_tx_pin(uart_debug_rx_pin), 						// note we flip TX/RX, recall "host_uart" represents your PC's UART connecting to this design
		.uart_rx_pin(uart_debug_tx_pin),
		.uart_tx_fifo_full(host_uart_tx_fifo_full),
		.uart_tx_fifo_empty(),
		.uart_rx_read(host_uart_rx_read),
		.uart_rx_ready(host_uart_rx_ready),
		.uart_rx_byte(host_uart_rx_byte)
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
        $dumpfile("debug_uart.vcd");
        $dumpvars(0, debug_uart_tb);
        
        clk = 0;
        rst_n = 0;
        prescaler = 2;
        prev_debug_incoming_tgl = 0;
        node_identity = 128'h12345678_11223344_55667788_99AABBCC;
        node_debug_outgoing_data = 128'hFEDCBA98_76543210_00112233_44556677;
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
		sf_buf[30:16] = 15'h1234;					// first address (pick something non zero)
		transmit_sfbuf(sf_buf);
		
		// read back enumeration
		test_phase = 1;
		sf_buf[30:16] = 15'h1235;					// we expect an enumeration of +1 back
		receive_sfbuf(sf_buf);

		// probe identity
		test_phase = 2;
		sf_buf[15:1]  = 15'h1234;
		sf_buf[0]	  = 0;							// READ
		sf_buf[23:16] = READ_CMD_IDENT;				// read identity
		transmit_sfbuf(sf_buf);
		
		// check feedback
		test_phase = 3;
		sf_buf[SF_BITS-1:16] = node_identity;
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
		sf_buf[SF_BITS-1:16] = node_debug_outgoing_data;
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
		wait (node_debug_incoming_tgl != prev_debug_incoming_tgl);
		prev_debug_incoming_tgl = node_debug_incoming_tgl;
		if (node_debug_incoming_data != sf_buf[SF_BITS-1:16]) begin
			for (i = 0; i < 128; i++) begin
				if (sf_buf[16+i] != node_debug_incoming_data[i]) begin
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
			// transmit over UART (we assume the FIFO_DEPTH > SF_BITS/8
			for (x = 0; x < SF_BITS/8; x++) begin
				while (host_uart_tx_fifo_full == 1);
				host_uart_tx_data_in 	= bits[SF_BITS-1:SF_BITS-8];
				host_uart_tx_start 		= 1;
				bits 					= {bits[SF_BITS-9:0], 8'b0};
				@(posedge clk); #1;
				host_uart_tx_start      = 0;
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
			// read over UART
			for (x = 0; x < SF_BITS/8; x++) begin
				wait(host_uart_rx_ready == 1);			// wait for ready
				host_uart_rx_read = 1;
				@(posedge clk); #1;
				host_uart_rx_read = 0;
				@(posedge clk); #1;
				bits = {bits[SF_BITS-9:0], host_uart_rx_byte};
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
