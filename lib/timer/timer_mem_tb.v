`timescale 1ns/1ps

module timer_mem_tb();

	reg clk;
	reg rst_n;
	reg bus_enable;
	reg bus_wr_en;
	reg [31:0] bus_addr;
	reg [31:0] bus_i_data;
	reg [3:0] bus_be;
	wire bus_ready;
	wire [31:0] bus_o_data;
	wire bus_irq;
	wire bus_err;
	wire pwm;
	reg [7:0]test_phase;
	reg [15:0] top_cnt;
	reg [15:0] cmp_cnt;
	reg [7:0] prescaler;
	
	timer_mem#(.ADDR_WIDTH(32), .DATA_WIDTH(32)) timer_mem_dut(
		.clk(clk), .rst_n(rst_n),
		.enable(bus_enable), .wr_en(bus_wr_en),
		.addr(bus_addr), .i_data(bus_i_data), .be(bus_be),
		.ready(bus_ready), .o_data(bus_o_data), .irq(bus_irq), .bus_err(bus_err), .pwm(pwm));

/*
    // common bus in
    input clk,
    input rst_n,            // active low reset
    input enable,           // active high overall enable (must go low between commands)
    input wr_en,            // active high write enable (0==read, 1==write)
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] i_data,
    input [DATA_WIDTH/8-1:0] be,       // lane 0 must be asserted, other lanes can be asserted but they're ignored.

    // common bus out
    output reg ready,       // active high signal when o_data is ready (or write is done)
    output reg [DATA_WIDTH-1:0] o_data,
    output wire irq,        // active high IRQ pin
    output wire bus_err,    // active high error signal

    // peripheral specific
    output pwm
*/

    // Parameters
    localparam CLK_PERIOD = 20;    // 50MHz
	
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Test Logic ---
    integer i;
    
    initial begin
        // Waveform setup
        $dumpfile("timer_mem.vcd");
        $dumpvars(0, timer_mem_tb);

        // Initialize
        clk = 0;
        rst_n = 0;
        bus_enable = 0;
        bus_wr_en = 0;
        bus_addr = 0;
        bus_i_data = 0;
        bus_be = 0;
        test_phase = 0;
        top_cnt = 16;
        cmp_cnt = 7;
        prescaler = 4;

        // Reset system
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);

		$display("Writing (and reading) TOP_CNT");
			// try writing TOP_CNT with 16-bit
			write_bus(32'h0, {16'b0, top_cnt}, 4'b0011, 0);
			
			// try reading it back as 16-bit
			read_bus(32'h0, 4'b0011, 0, {16'b0, top_cnt});

			// now do 8-bit writes
			write_bus(32'h0, {24'b0, top_cnt[7:0]}, 4'b0001, 0);
			write_bus(32'h4, {24'b0, top_cnt[15:8]}, 4'b0001, 0);

			// now 8-bit reads
			read_bus(32'h0, 4'b0001, 0, {24'b0, top_cnt[7:0]});
			read_bus(32'h4, 4'b0001, 0, {24'b0, top_cnt[15:8]});
		$display("PASSED.");
		test_phase = 1;
		$display("Loading other parameters");
			write_bus(32'h8, {16'b0, cmp_cnt}, 4'b0011, 0);		// compare count
			write_bus(32'h10, {24'b0, prescaler}, 4'b0001, 0);	// prescaler
			write_bus(32'h14, {30'b0, 2'b10}, 4'b0001, 0); // cmp count interrupt
			write_bus(32'h1c, {31'b0, 1'b1}, 4'b0001, 0); // enable counter
		$display("PASSED");
		test_phase = 2;
		for (i = 0; i < 28; i++) begin
			@(posedge clk);
			if (bus_irq != (((i%28)/4) == 7)) begin
				$display("bus_irq should be low until 7th clock, %d, %d", i, bus_irq);
				repeat(16) @(posedge clk);
				$fatal;
			end 
		end
		test_phase = 3;
		write_bus(32'h18, {30'b0, 2'b11}, 4'b0001, 0); // clear ints
		write_bus(32'h14, {30'b0, 2'b11}, 4'b0001, 0); // cmp count and top count interrupt
		if (bus_irq) begin
			$display("IRQ should be low by now");
			repeat(16) @(posedge clk);
			$fatal;
		end
		test_phase = 4;
		for (i = 0; i < 256; i++) begin
			@(posedge clk);
			if (bus_irq) begin
				write_bus(32'h18, {30'b0, 2'b11}, 4'b0001, 0); // clear ints
				check_irq(0);
			end
		end
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
			@(posedge clk);
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
			@(posedge clk);
			@(posedge clk);
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
			bus_addr = address;
			bus_be = be;
			bus_enable = 1;
			@(posedge clk);
			@(posedge clk);
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
				$display("ASSERTION ERROR: Invalid data read back bus=%h vs exp=%h", bus_o_data, expected);
				repeat(16) @(posedge clk);
				$fatal;
			end
			bus_enable = 0;
			//@(posedge clk);
		end
	endtask
endmodule
