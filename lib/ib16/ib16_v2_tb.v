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
	ib16 #(
		.STACK_ADDRESS(16'h1F00),		// configure for 8K model (add 6000 to both in 32K model)
		.IRQ_VECTOR(16'h1E00),
		.BOOT_ROM_ADDR(16'hF000),
		.TWO_CYCLE(1))
	ib16dut(
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
	reg [7:0] demo_rom[0:32767];
	reg [14:0] demo_idx;
	wire [15:0] rom_address = bus_address - 16'hF000;
	
	// simple enable/ready handshake on memory
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			bus_ready 		<= 0;
			bus_data_out 	<= 0;
			bus_irq 		<= 0;
			demo_idx 		<= 15'h7FFE; // invalid address in STACK space tells us to send 0x5A
			additional_cycles <= 0; // on the real device we take multiple cycles per memory access so we add them back here
		end else begin
			if (bus_enable & !bus_ready) begin
				if (bus_address < 16'h8000) begin
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
				end  if (bus_address >= 16'hF000 && bus_address < 16'hF100) begin
					if (bus_wr_en) begin
					end else begin
						// reads
						bus_data_out[7:0] <= boot_rom[rom_address[7:0]];
						if (bus_burst) begin
							additional_cycles <= additional_cycles + 0; // 1 cycles for a 16-bit read
							bus_data_out[15:8] <= boot_rom[rom_address[7:0]+1];
						end else begin
							additional_cycles <= additional_cycles + 0; // 1 cycles for a 8-bit read
						end
					end
				end if (bus_address == 16'hFFFF) begin
					if (bus_wr_en) begin
					end else begin
						// reads
						if (demo_idx == 15'h7FFE) begin
							bus_data_out[7:0] <= 8'h5A;					// magic byte
						end else if (demo_idx == 15'h7FFF) begin
							bus_data_out[7:0] <= 8'h1F;					// number of 256 byte blocks 
						end else begin
							bus_data_out[7:0] <= demo_rom[demo_idx];
						end
						demo_idx <= demo_idx + 1'b1;
						bus_data_out[15:8] <= 0;
						additional_cycles <= additional_cycles + 0;
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
		$readmemh("ecp5_demo.s.hex", demo_rom);
		$readmemh("boot_rom.s.hex", boot_rom);
		clk = 0;
		rst_n = 0;

		repeat(3) @(posedge clk);
		rst_n = 1;
		repeat(8192) begin
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
