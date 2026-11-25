/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
`timescale 1ns/1ps

module spi_tb();
	reg clk;
	reg rst_n;

    localparam CLK_PERIOD = 20;    //  50MHz
	
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Test Logic ---
	reg test_done = 0;
	reg test_fail = 0;
	reg test2_done = 0;
	reg test2_fail = 0;
    reg [3:0] test_state;
    reg [3:0] test_tag;
    
	initial begin
        // Waveform setup
        $dumpfile("spi_tb.vcd");
        $dumpvars(0, spi_tb);

		rst_n = 0;
		clk   = 0;

		while(test_done == 0 || test2_done == 0) @(posedge clk);
		if (test_fail || test2_fail) begin
			$display("Test failed\n");
			$fatal;
		end
        $finish;
	end

    // Instantiate both modules
    reg        spi_valid;
    wire       spi_idle;
    reg        spi_cs_start;
    reg        spi_cs_end;
    reg [7:0]  spi_mosi_byte;
    wire [7:0] spi_miso_byte;

    wire       cs_pin;
    wire       sck_pin;
    wire       mosi_pin;
    wire       miso_pin;

    // controller
    spi spi_dut(
        .clk(clk), .rst_n(rst_n),
        .valid(spi_valid), .idle(spi_idle),
        .div(4'd0),
        .cs_start(spi_cs_start), .cs_end(spi_cs_end),
        .mosi_byte(spi_mosi_byte), .miso_byte(spi_miso_byte),
        .cs_pin(cs_pin), .sck_pin(sck_pin), .mosi_pin(mosi_pin), .miso_pin(miso_pin)
    );

    wire       spip_ready;
    wire [7:0] spip_mosi_byte;
    reg [7:0]  spip_miso_byte;

    // peripheral
    spip spip_dut(
        .clk(clk), .rst_n(rst_n),
        .ready(spip_ready),
        .mosi_byte(spip_mosi_byte), .miso_byte(spip_miso_byte),
        .cs_pin(cs_pin), .sck_pin(sck_pin), .mosi_pin(mosi_pin), .miso_pin(miso_pin)
    );

    // create two FF blocks for the two, transfer 0x11 0x22 from controller to peripheral, and 0x33 0x44 back

    // controller test
    reg [1:0] test_spi_cnt;         // which byte are we transmitting
    always @(posedge clk) begin
        spi_valid <= 1'b0;
        if (~spi_valid & spi_idle) begin
            // program next byte
            test_spi_cnt <= test_spi_cnt + 1;
            case (test_spi_cnt)
                0: begin
                    // expect 0x33 and write 0x22
                    if (spi_miso_byte != 8'h33) begin
                        $display("Invalid spi_miso_byte(%d) expected 33 got %x", test_spi_cnt, spi_miso_byte);
                        test_fail <= 1;
                    end
                    spi_mosi_byte <= 8'h22;
                    spi_valid     <= 1;
                    spi_cs_end    <= 1;       // raise CS at end of transfer
                end
                1: begin
                    // expect 0x44 and halt
                    test_done <= 1;
                    if (spi_miso_byte != 8'h44) begin
                        $display("Invalid spi_miso_byte(%d) expected 44 got %x", test_spi_cnt, spi_miso_byte);
                        test_fail <= 1;
                    end
                end
            endcase
        end

        if (~rst_n) begin
            test_spi_cnt  <= 0;
            rst_n         <= 1'b1;
            // initiate the start of sending 0x11
            spi_valid     <= 1'b1;
            spi_mosi_byte <= 8'h11;
            spi_cs_start  <= 1'b0;
            spi_cs_end    <= 1'b0;
        end
    end

    // peripheral test
    always @(posedge clk) begin
        if (spip_ready) begin
            // program next byte
            case (test_spi_cnt)
                0: begin
                    // expect 0x11 and write 0x44
                    if (spip_mosi_byte != 8'h11) begin
                        $display("Invalid spip_mosi_byte expected 11 got %x", spip_mosi_byte);
                        test2_fail <= 1;
                    end
                    spip_miso_byte <= 8'h44;
                end
                1: begin
                    // expect 0x44 and halt
                    test2_done <= 1;
                    if (spip_mosi_byte != 8'h22) begin
                        $display("Invalid spip_mosi_byte expected 22 got %x", spip_mosi_byte);
                        test2_fail <= 1;
                    end
                end
            endcase
        end

        if (~rst_n) begin
            // initiate the start of sending 0x33
            spip_miso_byte <= 8'h33;
        end
    end
endmodule

`include "spi.v"
`include "spip.v"
