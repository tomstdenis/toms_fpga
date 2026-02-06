`timescale 1ns/1ps

module uart_full_loopback_tb();
    // Global Control
    reg clk;
    reg rst_n;
    reg [15:0] baud_div;

    // TX Signals
    reg start_tx;
    reg [7:0] tx_data_in;
    wire tx_pin;
    wire tx_done;
	wire tx_started;

    // RX Signals
    reg rx_read;
    wire rx_done;
    wire [7:0] rx_byte_out;

    // Parameters
    localparam CLK_PERIOD = 20;    // 50MHz
    localparam BAUD_VALUE = 434;   // 115200 Baud
    
    // 1. Instantiate verified TX Module
    tx_uart dut_tx (
        .clk(clk),
        .rst_n(rst_n),
        .baud_div(baud_div),
        .start_tx(start_tx),
        .data_in(tx_data_in),
        .tx_pin(tx_pin), // Connects to RX pin
        .tx_done(tx_done),
		.tx_started(tx_started)
    );

    // 2. Instantiate RX Module to be tested
    rx_uart dut_rx (
        .clk(clk),
        .rst_n(rst_n),
        .baud_div(baud_div),
        .rx_pin(tx_pin),  // Direct loopback
        .rx_read(rx_read),
        .rx_done(rx_done),
        .rx_byte(rx_byte_out)
    );

    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Test Logic ---
    integer i;
    
    initial begin
        // Waveform setup
        $dumpfile("rx_uart.vcd");
        $dumpvars(0, uart_full_loopback_tb);

        // Initialize
        clk = 0;
        rst_n = 0;
        start_tx = 0;
        rx_read = 0;
        baud_div = BAUD_VALUE;
        tx_data_in = 0;

        // Reset system
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);

        $display("Starting Loopback Test: All 256 bytes...");

        for (i = 0; i < 256; i = i + 1) begin
            send_and_verify(8'hff ^ i[7:0]);
        end

        $display("\n[SUCCESS] All 256 bytes verified in loopback!");
        $finish;
    end

    // Task: Handle the TX->RX flow and assertion
    task send_and_verify(input [7:0] data_to_send);
        begin
			// rx done should be clear
			if (rx_done !== 0) begin
				$display("ASSERTION FAILED: rx_done not low to start test\n");
				$fatal;
			end
			
            // 1. Trigger TX
            @(posedge clk);
            tx_data_in = data_to_send;
            start_tx = 1;
            @(posedge clk);
            start_tx = 0;
            @(posedge clk);
            
            // TX should be started by now ...
			if (tx_started !== 1) begin
				$display("ASSERTION FAILED: tx_stated should be high by now\n");
				$fatal;
			end
	
			// wait for TX to be done
			wait(tx_done == 1'b1);
	
            // 2. Wait for RX to finish (with a Watchdog/Timeout)
            fork : wait_or_timeout
                begin
                    wait(rx_done == 1'b1);
                    disable wait_or_timeout;
                end
                begin
                    // Calculate a generous timeout (baud * 12 bits)
                    repeat(BAUD_VALUE * 15) @(posedge clk);
                    $display("ERROR: Timeout waiting for rx_done at byte 0x%h", data_to_send);
                    $fatal;
                end
            join

            // 3. Automated Assertion
            if (rx_byte_out !== data_to_send) begin
                $display("ASSERTION FAILED! Sent: 0x%h, Received: 0x%h", data_to_send, rx_byte_out);
                $fatal;
            end else begin
                $display("PASS: 0x%h", data_to_send);
            end

            // 4. Clear the RX flag (Pulse rx_read)
            @(posedge clk);
            rx_read = 1;
            @(posedge clk);
            rx_read = 0;
            @(posedge clk);
            
			// 5. Ensure rx_done is clear
			if (rx_done !== 0) begin
				$display("ASSERTION FAILED: rx_done was not cleared by pulsing rx_read\n");
				$fatal;
			end
            
            // Short gap between bytes
            repeat(10) @(posedge clk);
        end
    endtask

endmodule
