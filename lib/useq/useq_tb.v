`timescale 1ns/1ps

module useq_tb();

	reg [7:0] mem[0:255];
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
    reg [7:0] T_PC;
    reg [7:0] T_A;
    reg [7:0] T_LR;
    reg [7:0] T_ILR;
    reg [7:0] T_R [15:0];
    
	integer i;
	integer j;
    initial begin
        // Setup for OSS CAD (GTKWave)
        $dumpfile("useq.vcd");
        $dumpvars(0, useq_tb);

		$readmemh("test1_clean.hex", mem);
		reset_cpu();
		
		repeat(64) step_cpu();
        
		$finish;
	end

    task step_cpu();
		integer x;reg [7:0] ttpc;
		begin
			ttpc = useq_dut.PC;
			@(posedge clk);
			$write("CPU: inst=%2h PC=%2h, A=%2h LR=%2h ILR=%2h OP=%2h R=[", useq_dut.instruct, useq_dut.PC, useq_dut.A, useq_dut.LR, useq_dut.ILR, o_port);
			for (x = 0; x < 16; x++) begin
				$write("%2h", useq_dut.R[x]);
				if (x < 15) begin
					$write(" ");
				end
			end
			$write("]\n");
		end
	endtask

	task reset_cpu();
		integer x;
		begin
			// Initialize signals
			clk = 0;
			rst_n = 0;
			i_port = 8'hAB;
			read_fifo = 0;
			write_fifo = 0;
			T_PC = 0;
			T_A = 0;
			T_LR = 0;
			T_ILR = 0;
			for (x = 0; x < 16; x++) begin
				T_R[x] = 0;
			end
		
			// Reset
			repeat(5) @(posedge clk);
			rst_n = 1;
		end
	endtask
endmodule

