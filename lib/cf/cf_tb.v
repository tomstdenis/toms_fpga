`timescale 1ns/1ps

module cf_tb();
	reg clk;
	reg rst_n;
	
	// memory
	reg [7:0] mem[0:65535];
	wire [16:0] mem_addr;
	wire mem_wr_en;
	reg [15:0] mem_data_out;
	wire [15:0] mem_data_in;
	wire mem_burst;
	reg mem_ready;
	wire mem_enable;
	wire mem_io_flag;
	
	always @(posedge clk) begin
		if (!rst_n) begin
			mem_data_out <= 0;
			mem_ready <= 0;
		end else begin
			if (mem_enable && !mem_ready) begin
				mem_ready <= 1;
				if (!mem_io_flag) begin
					mem_data_out <= { mem_burst ? mem[mem_addr[15:0] + 1] : 8'h0, mem[mem_addr[15:0]] };
					if (mem_wr_en) begin
						mem[mem_addr[15:0]] <= mem_data_in[7:0];
						if (mem_burst) begin
							mem[mem_addr[15:0] + 1] <= mem_data_in[15:8];
						end
					end
				end
			end
			if (mem_ready && !mem_enable) begin
				mem_ready <= 0;
			end
		end
	end
	
	cf_cpu cf_dut(
		.clk(clk), .rst_n(rst_n),
		.bus_address(mem_addr), .bus_io_flag(mem_io_flag), .bus_burst(mem_burst),
		.bus_data_in(mem_data_in), .bus_enable(mem_enable), .bus_ready(mem_ready),
		.bus_data_out(mem_data_out), .bus_wr_en(mem_wr_en)
	);
	
    // Parameters for the simulation
    localparam CLK_PERIOD = 20; // 50MHz Clock
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;
    
    integer i;
	
	initial begin
        // Waveform setup
        $dumpfile("cf_tb.vcd");
        $dumpvars(0, cf_tb);
		clk = 0;
		rst_n = 0;
		
		$readmemh("lds.hex", mem);

        // Reset system
        repeat(3) @(posedge clk);
        rst_n = 1;
		@(posedge clk); #1;

		repeat(1024) @(posedge clk);

		$finish;
	end
endmodule
