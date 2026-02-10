`timescale 1ns/1ps

module useq_tb();

	reg [7:0] mem[255:0];
	wire [7:0] mem_addr;
	wire [7:0] mem_data;
	
	assign mem_data = mem[mem_addr];
	
	reg clk;
	reg rst_n;
	reg [7:0] i_port;
	wire [7:0] o_port;

	useq useq_dut(.clk(clk), .rst_n(rst_n), .mem_data(mem_data), .i_port(i_port), .mem_addr(mem_addr), .o_port(o_port));

    // Parameters for the simulation
    localparam CLK_PERIOD = 20; // 50MHz Clock
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // --- Verification Logic ---
    
	integer i;
	integer j;
    initial begin
        // Setup for OSS CAD (GTKWave)
        $dumpfile("useq.vcd");
        $dumpvars(0, useq_tb);

        // Initialize signals
        clk = 0;
        rst_n = 0;
		$readmemh("blink_clean.hex", mem);
    
        // Reset
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        

		repeat(4096) @(posedge clk);
		$finish;
	end
endmodule

