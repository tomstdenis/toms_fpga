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
	reg [31:0] cycles;
	reg [31:0] inst_cnt;
	reg prev_cf_fetch;

	always @(posedge clk) begin
		if (!rst_n) begin
			mem_data_out <= 0;
			mem_ready <= 0;
			cycles <= 0;
			inst_cnt <= 0;
		end else begin
			if (prev_cf_fetch != cf_dut.cf_start_fetch && cf_dut.cf_start_fetch) begin
				inst_cnt <= inst_cnt + 1;
			end
			prev_cf_fetch <= cf_dut.cf_start_fetch;
			cycles <= cycles + 1;
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
    always #(CLK_PERIOD/2) begin clk = ~clk; end
    
    integer i;
    
	initial begin
        // Waveform setup
        $dumpfile("cf_tb.vcd");
        $dumpvars(0, cf_tb);
		clk = 0;
		rst_n = 0;
		inst_cnt = 0;
		
		$readmemh("lds.hex", mem);

        // Reset system
        repeat(3) @(posedge clk); #1
        rst_n = 1;

		// step 1024 opcodes
		i = 1024;
		while (inst_cnt < 1024) begin
			i = i + 1;
			case(i)
				// do all 8 variants for LD
				default: // LD #5AA5
					begin
						mem[0] = 8'h00;
						mem[1] = 8'hA5;
						mem[2] = 8'h5A;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != (3 + 1) || cf_dut.reg_ACC != 16'h5AA5) fail_code();
						i = 0;
					end
				1: // LD (100h)
					begin
						mem[256] = 8'h11;			// store 2211 at address 0x100
						mem[257] = 8'h22;
						mem[0]   = 8'h01;			// LD 256
						mem[1]   = 8'h00;
						mem[2]   = 8'h01;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != (3 + 1) || cf_dut.reg_ACC != 16'h2211) fail_code();
					end
				2: // LD I
					begin
						mem[256] = 8'h33;			// store 4433 at address 0x100
						mem[257] = 8'h44;
						mem[0]   = 8'h02;			// LD I
						cf_dut.reg_PC = 0;
						cf_dut.reg_INDEX = 16'h0100; // INDEX = 100h
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != (1 + 1) || cf_dut.reg_ACC != 16'h4433) fail_code();
					end
				3: // LD n,I
					begin
						mem[256] = 8'h55;			// store 6655 at address 0x100
						mem[257] = 8'h66;
						mem[0]   = 8'h03;			// LD n,I
						mem[1]   = 8'h10;			// n == 10h
						cf_dut.reg_PC = 0;
						cf_dut.reg_INDEX = 16'h0100 - 16'h0010; // INDEX = 100h - 10h
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != (2 + 1) || cf_dut.reg_ACC != 16'h6655) fail_code();
					end
				4: // LD n,S
					begin
						mem[256] = 8'h88;			// store 8877 at address 0x100
						mem[257] = 8'h77;
						mem[0]   = 8'h04;			// LD n,S
						mem[1]   = 8'h10;			// n == 10h
						cf_dut.reg_PC = 0;
						cf_dut.reg_SP = 16'h0100 - 16'h0010; // SP = 100h - 10h
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != (2 + 1) || cf_dut.reg_ACC != 16'h7788) fail_code();
					end
				5: // LD S+
					begin
						mem[256] = 8'h99;			// store AA99 at address 0x100
						mem[257] = 8'hAA;
						mem[0]   = 8'h05;			// LD S+
						cf_dut.reg_PC = 0;
						cf_dut.reg_SP = 16'h0100; // SP = 100h
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != (1 + 1) || cf_dut.reg_ACC != 16'hAA99 || cf_dut.reg_SP != 16'h0102) fail_code();
					end
				6: // LD [S+]
					begin
						mem[256] = 8'hBB;			// store CCBB at address 0x100
						mem[257] = 8'hCC;
						mem[258] = 8'h00;			// store indirect pointer tat 0x102 pointing to 0x100
						mem[259] = 8'h01;
						mem[0]   = 8'h06;			// LD [S+]
						cf_dut.reg_PC = 0;
						cf_dut.reg_SP = 16'h0102;   // SP = 102h
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != (1 + 1) || cf_dut.reg_ACC != 16'hCCBB || cf_dut.reg_SP != 16'h0104) fail_code();
					end
				7: // LD [S]
					begin
						mem[256] = 8'hDD;			// store EEDD at address 0x100
						mem[257] = 8'hEE;
						mem[258] = 8'h00;			// store indirect pointer tat 0x102 pointing to 0x100
						mem[259] = 8'h01;
						mem[0]   = 8'h07;			// LD [S]
						cf_dut.reg_PC = 0;
						cf_dut.reg_SP = 16'h0102;   // SP = 102h
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != (1 + 1) || cf_dut.reg_ACC != 16'hEEDD || cf_dut.reg_SP != 16'h0102) fail_code();
					end
					
				// do 1 variant for rest of ALU Commands...
				8: // LDB #5A
					begin
						mem[0] = 8'h08;
						mem[1] = 8'h5A;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != (2 + 1) || cf_dut.reg_ACC != 16'h005A) fail_code();
					end
			endcase
		end
		$display("Ran %d opcodes in %d cycles (%d per inst)", inst_cnt, cycles, (cycles * 100) / inst_cnt); 

		$finish;
	end
	
	task fail_code();
		begin
			$display("Failed test #%d", i);
			$display("PC=%x ACC=%x INDEX=%x SP=%x", cf_dut.reg_PC, cf_dut.reg_ACC, cf_dut.reg_INDEX, cf_dut.reg_SP);
			$fatal;
		end
	endtask
	
    task step_opcode();
		begin
			while (cf_dut.fsm_state == 0) begin
				@(posedge clk);
			end
			while (cf_dut.fsm_state != 0) begin
				@(posedge clk);
			end
			#1;
		end
	endtask
endmodule
