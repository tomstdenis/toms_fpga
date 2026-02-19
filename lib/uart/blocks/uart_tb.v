`timescale 1ns/1ps

module uart_tb();
	reg clk;
	reg rst_n;
	reg [15:0] baud_div;
	reg uart_tx_start;
	reg [7:0] uart_tx_data_in;
	wire uart_tx_pin;
	wire uart_tx_fifo_full;
	wire uart_tx_fifo_empty;
	
	reg uart_rx_read;
	wire uart_rx_ready;
	wire [7:0] uart_rx_byte;
	
/*
module uart#(parameter FIFO_DEPTH=64, RX_ENABLE=1, TX_ENABLE=1)
(
    input clk,                      // main clock
    input rst_n,                      // active low reset
    input [15:0] baud_div,          // counter value for baud calculation (e.g. F_CLK/BAUD == baud_div)
    input uart_tx_start,            // signal we want to load uart_tx_data_in into the TX FIFO
    input [7:0] uart_tx_data_in,    // TX data
    output uart_tx_pin,             // (out) pin for transmitting on
    output uart_tx_fifo_full,       // (out) true if the FIFO is currently full
    output uart_tx_fifo_empty,      // (out) true if the FIFO is empty

    input uart_rx_pin,              // pin to RX from
    input uart_rx_read,             // signal that we read a byte
    output uart_rx_ready,       // (out) signal that an output byte is available
    output [7:0] uart_rx_byte       // (out) the RX byte
);
*/
    localparam fd = 64;


	uart #(.FIFO_DEPTH(fd), .TX_ENABLE(1), .RX_ENABLE(1))
	uart_dut(.clk(clk), .rst_n(rst_n), .baud_div(baud_div), 
		// TX block
		.uart_tx_start(uart_tx_start), 
		.uart_tx_data_in(uart_tx_data_in),
		.uart_tx_pin(uart_tx_pin),
		.uart_tx_fifo_full(uart_tx_fifo_full),
		.uart_tx_fifo_empty(uart_tx_fifo_empty),
		// RX block
		.uart_rx_read(uart_rx_read),
		.uart_rx_ready(uart_rx_ready),
		.uart_rx_byte(uart_rx_byte),
		.uart_rx_pin(uart_tx_pin));

    // Parameters
    localparam CLK_PERIOD = 20;    // 50MHz
    localparam BAUD_VALUE = 434;   // 115200 Baud
	
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Test Logic ---
    integer i;
    integer j;
    integer n;
    initial begin
        // Waveform setup
        $dumpfile("uart.vcd");
        $dumpvars(0, uart_tb);

        // Initialize
        clk = 0;
        rst_n = 0;
        baud_div = BAUD_VALUE;
        uart_tx_start = 0;
        uart_rx_read = 0;
        uart_tx_data_in = 0;

        // Reset system
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);

		// test idle conditions to start
		$display("Initial Idle Test: ");
		test_idle_conditions();
		$display("PASSED\n");
		
		// out of init a read should just return zero
		$display("Testing idle read...");
		recv_byte(0, 0);
		$display("PASSED");
		
		// loop over just under to just over the FIFO max size
		for (j = fd - 4; j < fd + 4; j++) begin
			n = (j > fd) ? fd : j;

			// now try to write 64 bytes and read it back
			$display("Sending %d bytes...", j);
			for (i = 0; i < j; i++) begin
				send_byte(8'b1 + i[7:0]);
				if (i == fd) begin
					// FIFO should be full now
					test_fifo_full(1);
				end
			end

			// wait for the byte to send
			repeat(j * 15 * BAUD_VALUE) #CLK_PERIOD;

			// now read back (should get the first 64 bytes back not the 65'th
			$display("Reading %d bytes...", n);
			for (i = 0; i < n; i++) begin
				recv_byte(8'b1 + i[7:0], 1);
			end
			@(posedge clk);
			#1;
			$display("PASSED");
		end

		// test rest conditions...
		$display("Testing rest conditions...");
		test_fifo_empty(1);
		test_fifo_full(0);
		test_rx_ready(0);
		$display("PASSED");
		$finish;
    end
    
    task send_byte(input [7:0] val);
		begin
			@(posedge clk);
			#1;
			uart_tx_data_in = val;
			uart_tx_start = 1'b1;
			@(posedge clk);
			#1;
			uart_tx_start = 1'b0;
		end
	endtask
	
	task recv_byte(input [7:0] expected, input ready_expected);
		begin
			@(posedge clk);
			#1;
			test_rx_ready(ready_expected);
			uart_rx_read = 1'b1;
			@(posedge clk);
			#1;
			uart_rx_read = 1'b0;
			$display("read: %2h", uart_rx_byte);
			if (uart_rx_byte != expected) begin
				$display("ASSERTION FAILED: uart_rx_byte (%h) not expected value (%h)\n", uart_rx_byte, expected);
				$fatal;
			end
		end
	endtask
	
	task test_rx_ready(input expected);
		begin
			if (uart_rx_ready !== expected) begin
				$display("ASSERTION FAILED:  uart_rx_ready is not the expected value (%h)\n", expected);
				$fatal;
			end
		end
	endtask

	task test_fifo_empty(input expected);
		begin
			if (uart_tx_fifo_empty !== expected) begin
				$display("ASSERTION FAILED:  uart_tx_fifo_empty is not the expected value (%h)\n", expected);
				$fatal;
			end
		end
	endtask
	
	task test_fifo_full(input expected);
		begin
			if (uart_tx_fifo_full!== expected) begin
				$display("ASSERTION FAILED:  uart_tx_fifo_full is not the expected value (%h)\n", expected);
				$fatal;
			end
		end
	endtask

    task test_idle_conditions();
		begin
			// fifo should be TX=empty, TX=!full, RX != ready
			if (uart_tx_fifo_empty !== 1) begin
				$display("ASSERTION FAILED: uart_tx_fifo_empty is not 1 at idle\n");
				$fatal;
			end
			if (uart_tx_fifo_full !== 0) begin
				$display("ASSERTION FAILED: uart_tx_fifo_full is not 0 at idle\n");
				$fatal;
			end
			if (uart_rx_ready !== 0) begin
				$display("ASSERTION FAILED: uart_rx_ready is not 0 at idle\n");
				$fatal;
			end
		end
	endtask
endmodule
