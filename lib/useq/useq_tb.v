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
	wire fifo_full;
	wire [7:0] fifo_out;
	reg [7:0] fifo_in;

	useq #(.FIFO_DEPTH(2), .ISR_VECT(8'hF0), .ENABLE_EXEC1(1), .ENABLE_EXEC2(1), .ENABLE_IRQ(1), .ENABLE_HOST_FIFO_CTRL(1)) useq_dut(
		.clk(clk), .rst_n(rst_n), 
		.mem_data(mem_data), .i_port(i_port), 
		.mem_addr(mem_addr), .o_port(o_port),
		.read_fifo(read_fifo), .write_fifo(write_fifo), .fifo_empty(fifo_empty), .fifo_full(fifo_full),
		.fifo_out(fifo_out), .fifo_in(fifo_in));

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

/*
		$readmemh("test1_clean.hex", mem);
		i_port = 8'hAB;
		reset_cpu();
		repeat(48) step_cpu();
		
		$display("Trying out interrupts...");
		$readmemh("test2_clean.hex", mem);
		i_port = 8'h00;
		reset_cpu();
		repeat(10) step_cpu();
		$display("Should be triggering an IRQ now...\n");
		i_port = 8'h01;
		repeat(20) step_cpu(); // ensure IRQ doesn't trip again
		$display("Should be triggering another IRQ now...\n");
		i_port = 8'h02;
		repeat(20) step_cpu(); // ensure IRQ doesn't trip again
		$display("Should be triggering last IRQ now (back on pin 0)...\n");
		i_port = 8'h01;
		repeat(20) step_cpu(); // ensure IRQ doesn't trip again
		$display("Should NOT be triggering last IRQ now (on pin 7)...\n");
		i_port = 8'h80;
		repeat(20) step_cpu(); // ensure IRQ doesn't trip again
        
		$display("Trying out FIFOS...");
		$readmemh("test3_clean.hex", mem);
		reset_cpu();
		step_cpu();
		write_fifo = 1;
		fifo_in = 8'hCC;
		step_cpu();
		write_fifo = 0;
		step_cpu();
		write_fifo = 1;
		fifo_in = 8'hDD;
		step_cpu();
		write_fifo = 0;
		repeat(16) step_cpu();
		read_fifo = 1;
		repeat(10) begin
			step_cpu();
			if (fifo_empty) read_fifo = 0;
		end
*/
		$display("Trying out EXEC2...");
		$readmemh("test4_clean.hex", mem);
		reset_cpu();
		repeat(32) step_cpu();
		$finish;
	end

    task step_cpu();
		integer x;reg [7:0] ttpc;
		begin
			ttpc = useq_dut.PC;
			@(posedge clk);
			$write("CPU%1d: inst=%2h PC=%2h, A=%2h LR=%2h ILR=%2h OP=%2h FO=%2h FE=%d FF=%d R=[", useq_dut.mode, useq_dut.instruct, useq_dut.PC, useq_dut.A, useq_dut.LR, useq_dut.ILR, o_port, fifo_out, fifo_empty, fifo_full);
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
			read_fifo = 0;
			write_fifo = 0;
			fifo_in = 0;
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

