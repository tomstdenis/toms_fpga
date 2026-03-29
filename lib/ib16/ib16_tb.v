`timescale 1ns/1ps

module ib16_tb();
	reg clk;
	reg rst_n;

	wire bus_enable;
	wire bus_wr_en;
	wire [15:0] bus_address;
	wire [7:0] bus_data_in;
	reg bus_ready;
	reg [7:0] bus_data_out;
	reg bus_irq;
	
	ib16 ib16dut(
		.clk(clk), .rst_n(rst_n),
		.bus_enable(bus_enable),
		.bus_wr_en(bus_wr_en),
		.bus_address(bus_address),
		.bus_data_in(bus_data_in),
		.bus_ready(bus_ready),
		.bus_data_out(bus_data_out),
		.bus_irq(bus_irq));

	reg [7:0] tb_mem[0:8191];						// test bench memory
	
	// simple enable/ready handshake on memory
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			bus_ready 		<= 0;
			bus_data_out 	<= 0;
			bus_irq 		<= 0;
		end else begin
			if (bus_enable & !bus_ready) begin
				if (bus_address < 16'h2000) begin
					if (bus_wr_en) begin
						tb_mem[bus_address[12:0]] <= bus_data_in;
					end else begin
						bus_data_out <= tb_mem[bus_address[12:0]];
					end
				end // TODO: uart or something interesting here
				$display("bus transaction: wr_en(%d), bus_addr(%h), bus_data_in(%h), bus_data_out(%h)", bus_wr_en, bus_address, bus_data_in, bus_data_out);
				bus_ready	<= 1;
			end else if (!bus_enable & bus_ready) begin
				bus_ready 	<= 0;
			end
		end
	end

    // Parameters for the simulation
    localparam CLK_PERIOD = 20; // 50MHz Clock
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;
    
    integer i;
	
	initial begin
        // Waveform setup
        $dumpfile("ib16.vcd");
        $dumpvars(0, ib16_tb);
		$readmemh("tb_test.s.hex", tb_mem);
		clk = 0;
		rst_n = 0;

		repeat(3) @(posedge clk);
		rst_n = 1;
		repeat(65536) @(posedge clk);
		
		$finish;
	end
endmodule
