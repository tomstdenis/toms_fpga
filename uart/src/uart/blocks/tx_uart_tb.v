`timescale 1ns/1ps

module tx_uart_tb();
    // Signals
    reg clk;
    reg rst_n;
    reg [15:0] baud_div;
    reg start_tx;
    reg [7:0] data_in;
    wire tx_pin;
    wire tx_started;
    wire tx_done;

    // Parameters for the simulation
    localparam CLK_PERIOD = 20; // 50MHz Clock
    localparam BAUD_VALUE = 434; // Example for 115200 baud @ 50MHz

    // Instantiate the DUT
    tx_uart dut (
        .clk(clk),
        .rst_n(rst_n),
        .baud_div(baud_div),
        .start_tx(start_tx),
        .data_in(data_in),
        .tx_pin(tx_pin),
        .tx_started(tx_started),
        .tx_done(tx_done)
    );

    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Verification Logic ---
    
	integer i;
    initial begin
        // Setup for OSS CAD (GTKWave)
        $dumpfile("waveform.vcd");
        $dumpvars(0, tx_uart_tb);

        // Initialize signals
        clk = 0;
        rst_n = 0;
        start_tx = 0;
        data_in = 0;
        baud_div = BAUD_VALUE;

        // Reset
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        // Test Case 1: Send 0xA5 (10100101)
		for (i = 0; i < 256; i++) begin
			run_test(i[7:0]);
			repeat($urandom_range(1, 100)) @(posedge clk);	// wait some random delay before sending next
		end
	
	    $display("\n[ALL TESTS PASSED]");
        $finish;
    end

    // Task to trigger TX and monitor results simultaneously
    task run_test(input [7:0] test_data);
        begin
            $display("\n--- Testing Byte: 0x%h ---", test_data);
            
            fork
                // Process 1: The Driver
                begin
                    @(posedge clk);
                    data_in = test_data;
                    start_tx = 1;
                    @(posedge clk);
                    start_tx = 0;
                    wait(tx_done);
                end

                // Process 2: The Monitor (Automated Assertion)
                begin
                    check_tx_output(test_data);
                end
            join
        end
    endtask

    // The "Logic Analyzer" Task
    task check_tx_output(input [7:0] expected_byte);
        integer i;
        realtime bit_time;
        begin
            // Calculate timing: (baud_div + 1) * clock_period
            // Your module counts baud_div down to 0, so total cycles per bit = baud_div + 1
            bit_time = (baud_div + 1) * CLK_PERIOD;

            // 1. Wait for Start Bit (falling edge)
            @(negedge tx_pin);
            $display("[%t] Monitor: Detected Start Bit", $time);

            // 2. Jump to the middle of the first data bit
            #(bit_time * 1.5);

            // 3. Sample 8 Data Bits
            for (i = 0; i < 8; i = i + 1) begin
                $display("[%t] Monitor: Sampling Bit %d, found %b", $time, i, tx_pin);
                if (tx_pin !== expected_byte[i]) begin
                    $display("ASSERTION FAILED! Bit %d mismatch. Expected %b, got %b", i, expected_byte[i], tx_pin);
                    $fatal; // Kill simulation on error
                end
                #(bit_time);
            end

            // 4. Verify Stop Bit
            if (tx_pin !== 1'b1) begin
                $display("ASSERTION FAILED! Missing Stop Bit.");
                $finish;
            end
            $display("[%t] Monitor: Successfully verified Stop Bit", $time);
        end
    endtask
endmodule
