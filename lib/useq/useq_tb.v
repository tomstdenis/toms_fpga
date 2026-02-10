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
	reg read_fifo;
	reg write_fifo;
	wire fifo_empty;

	useq #(.FIFO_DEPTH(4), .ISR_VECT(8'hF0)) useq_dut(
		.clk(clk), .rst_n(rst_n), 
		.mem_data(mem_data), .i_port(i_port), 
		.mem_addr(mem_addr), .o_port(o_port),
		.read_fifo(read_fifo), .write_fifo(write_fifo), .fifo_empty(fifo_empty));


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
        i_port = 0;
        read_fifo = 0;
        write_fifo = 0;
		$readmemh("blink_clean.hex", mem);
    
        // Reset
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        

		repeat(4096) @(posedge clk);
		$finish;
	end
endmodule

