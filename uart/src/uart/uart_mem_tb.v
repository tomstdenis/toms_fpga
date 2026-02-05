`timescale 1ns/1ps

// addresses for various registers inside the block
`define UART_BAUD_L_ADDR       32'h0000
`define UART_BAUD_H_ADDR       32'h0004
`define UART_STATUS_ADDR       32'h0008
`define UART_DATA_ADDR         32'h000C
`define UART_INT_ADDR          32'h0010
`define UART_INT_PENDING_ADDR  32'h0014

// bit positions of the pending and enable interrupts
`define UART_INT_RX_READY     0
`define UART_INT_TX_EMPTY     1


module uart_mem_tb();

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
	reg [15:0] baud_div;
	reg [7:0] char;

	uart_mem #(.ADDR_WIDTH(32), .DATA_WIDTH(32))
	uart_mem_dut(.clk(clk), .rst_n(rst_n), 
		.enable(bus_enable), .wr_en(bus_wr_en), 
		.addr(bus_addr), .i_data(bus_i_data), .be(bus_be), 
		.ready(bus_ready), .o_data(bus_o_data), .irq(bus_irq), .bus_err(bus_err),
		.tx_pin(bus_tx_pin), .rx_pin(bus_tx_pin));

    // Parameters
    localparam CLK_PERIOD = 20;    // 50MHz
    localparam BAUD_VALUE = 434;   // 115200 Baud
	
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Test Logic ---
    integer i;
    
    initial begin
        // Waveform setup
        $dumpfile("uart_mem.vcd");
        $dumpvars(0, uart_mem_tb);

        // Initialize
        clk = 0;
        rst_n = 0;
        baud_div = BAUD_VALUE;
        bus_enable = 0;
        bus_wr_en = 0;
        bus_addr = 0;
        bus_i_data = 0;
        bus_be = 0;

        // Reset system
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);
        
		$display("Writing (and reading) BAUD");
			// try writing BAUD with 16-bit
			write_bus(32'h0, {16'b0, baud_div}, 4'b0011, 0);
			
			// try reading it back as 16-bit
			read_bus(32'h0, 4'b0011, 0, {16'b0, baud_div});

			// now do 8-bit writes
			write_bus(32'h0, {24'b0, baud_div[7:0]}, 4'b0001, 0);
			write_bus(32'h4, {24'b0, baud_div[15:8]}, 4'b0001, 0);

			// now 8-bit reads
			read_bus(32'h0, 4'b0001, 0, {24'b0, baud_div[7:0]});
			read_bus(32'h4, 4'b0001, 0, {24'b0, baud_div[15:8]});
		$display("PASSED.");
		
		// try some invalid ops
		$display("Trying some invalid unaligned stuff...");
			write_bus(32'h1, 0, 4'b1111, 1); // expect a bus error writing 32-bits to 1 mod 4
			write_bus(32'h2, 0, 4'b1111, 1); // expect a bus error writing 32-bits to 2 mod 4
			write_bus(32'h3, 0, 4'b1111, 1); // expect a bus error writing 32-bits to 3 mod 4
			write_bus(32'h1, 0, 4'b0011, 1); // expect a bus error writing 16-bits to 1 mod 2
		$display("PASSED.");
		
		// try writing to an invalid address
		$display("Trying some invalid addresses...");
			write_bus(32'h18, 0, 4'b1111, 1); // h14 is the last valid address so write to 0x18
			write_bus(32'h16, 0, 4'b0011, 1); // or 0x16 as 16-bits
			write_bus(32'h15, 0, 4'b0001, 1); // or 0x15 as 8-bits
		$display("PASSED.");

		// let's try the UART out
		$display("Trying to echo a byte through the UART");
			char = 8'hAA;
			$display("Checking if RX_READY is clear initially...");
			read_bus(32'h8, 4'b0001, 0, {32'b0});			// read STATUS, lsb should be CLEAR (!RX_READY)
			$display("Writing 0xAA to DATA");
			write_bus(32'hC, {24'b0, char}, 4'b0001, 0);
			// wait for the byte to send
			repeat(8 + 15 * BAUD_VALUE) @(posedge clk);
			$display("Checking if RX_READY is not clear after sending...");
			read_bus(32'h8, 4'b0001, 0, {31'b0, 1'b1});		// read STATUS, lsb should be set (RX_READY)
			read_bus(32'hC, 4'b0001, 0, {24'b0, char});		// lsb should be set
			read_bus(32'h8, 4'b0001, 0, {32'b0});			// read STATUS, lsb should be CLEAR (!RX_READY)
		$display("PASSED");
		$finish;
	end
	
    task write_bus(input [31:0] address, input [31:0] data, input [3:0] be, input bus_err_expected);
		begin
			@(posedge clk);
			if (bus_err !== 0) begin
				$display("ASSERTION ERROR: bus_err is not 0 in write_bus()");
				$fatal;
			end
			bus_wr_en = 1;
			bus_enable = 1;
			bus_addr = address;
			bus_be = be;
			bus_i_data = data;
			@(posedge clk);
			wait (bus_ready == 1);
			if (!bus_err_expected && bus_err !== 0) begin
				$display("ASSERTION ERROR: bus_err is not 0 in write_bus()");
				$fatal;
			end
			bus_enable = 0;
			@(posedge clk);
		end
	endtask
	
    task read_bus(input [31:0] address, input [3:0] be, input bus_err_expected, input [31:0] expected);
		begin
			@(posedge clk);
			if (bus_err !== 0) begin
				$display("ASSERTION ERROR: bus_err is not 0 in read_bus()");
				$fatal;
			end
			bus_wr_en = 0;
			bus_enable = 1;
			bus_addr = address;
			bus_be = be;
			@(posedge clk);
			wait (bus_ready == 1);
			if (!bus_err_expected && bus_err !== 0) begin
				$display("ASSERTION ERROR: bus_err is not 0 in read_bus()");
				$fatal;
			end
			if (bus_o_data !== expected) begin
				$display("ASSERTION ERROR: Invalid data read back %h vs %h", bus_o_data, expected);
				$fatal;
			end
			bus_enable = 0;
			@(posedge clk);
		end
	endtask
endmodule
