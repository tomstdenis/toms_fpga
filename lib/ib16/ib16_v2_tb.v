`timescale 1ns/1ps

module ib16_v2_tb();
	reg clk;
	reg rst_n;

	wire bus_enable;
	wire bus_wr_en;
	wire [15:0] bus_address;
	wire bus_burst;
	wire [15:0] bus_data_in;
	reg bus_ready;
	reg [15:0] bus_data_out;
	reg bus_irq;
	reg [31:0] additional_cycles;
	reg [7:0] ucode;
	ib16 ib16dut(
		.clk(clk), .rst_n(rst_n),
		.bus_enable(bus_enable),
		.bus_wr_en(bus_wr_en),
		.bus_burst(bus_burst),
		.bus_address(bus_address),
		.bus_data_in(bus_data_in),
		.bus_ready(bus_ready),
		.bus_data_out(bus_data_out),
		.bus_irq(bus_irq));

	reg [7:0] tb_mem[0:65535];						// test bench memory
	reg [7:0] boot_rom[0:255];
	wire [15:0] rom_address = bus_address - 16'h2000;
	
	// simple enable/ready handshake on memory
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			bus_ready 		<= 0;
			bus_data_out 	<= 0;
			bus_irq 		<= 0;
			ucode			<= 8'h5A;
			additional_cycles <= 0; // on the real device we take multiple cycles per memory access so we add them back here
		end else begin
			if (bus_enable & !bus_ready) begin
				if (bus_address < 16'h2000) begin
					if (bus_wr_en) begin
						// writes
						tb_mem[bus_address] <= bus_data_in[7:0];
						if (bus_burst) begin
							additional_cycles <= additional_cycles + 2; // 3 cycles for a 16-bit write
							tb_mem[bus_address + 1] <= bus_data_in[15:8];
						end else begin
							additional_cycles <= additional_cycles + 1; // 2 cycles for a 8-bit write
						end
					end else begin
						// reads
						bus_data_out[7:0] <= tb_mem[bus_address];
						if (bus_burst) begin
							additional_cycles <= additional_cycles + 3; // 4 cycles for a 16-bit read
							bus_data_out[15:8] <= tb_mem[bus_address+1];
						end else begin
							additional_cycles <= additional_cycles + 2; // 3 cycles for a 8-bit read
						end
					end
				end  if (bus_address >= 16'h2000 && bus_address < 16'h2100) begin
					if (bus_wr_en) begin
					end else begin
						// reads
						bus_data_out[7:0] <= boot_rom[rom_address[7:0]];
						if (bus_burst) begin
							additional_cycles <= additional_cycles + 1; // 4 cycles for a 16-bit read
							bus_data_out[15:8] <= boot_rom[rom_address[7:0]+1];
						end else begin
							additional_cycles <= additional_cycles + 0; // 3 cycles for a 8-bit read
						end
					end
				end  if (bus_address == 16'hFFFF) begin
					if (bus_wr_en) begin
					end else begin
						// reads
						bus_data_out[7:0] <= ucode;
						bus_data_out[15:8] <= 0;
						ucode			  <= 0;
						additional_cycles <= additional_cycles + 0; // 3 cycles for a 8-bit read
					end
				end
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
        $dumpfile("ib16_v2.vcd");
        $dumpvars(0, ib16_v2_tb);
		$readmemh("uart_demo.s.hex", tb_mem);
		$readmemh("boot_rom.s.hex", boot_rom);
		clk = 0;
		rst_n = 0;

		repeat(3) @(posedge clk);
		rst_n = 1;
		repeat(16384) begin
			bus_irq = 1;
			@(posedge clk); #1;
			bus_irq = 0;
			@(posedge clk); #1;
			repeat(29) @(posedge clk);
		end
		
		$display("Fetched %d instructions in %d cycles (%d cyclesx100 per instruction)", ib16dut.stats_fetches, ib16dut.stats_cycles + additional_cycles, ((ib16dut.stats_cycles + additional_cycles) * 100) / (ib16dut.stats_fetches - 1));
		$finish;
	end
endmodule
