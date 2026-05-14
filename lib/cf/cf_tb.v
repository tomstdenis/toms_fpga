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
				9: // ADD #1234
					begin
						mem[0] = 8'h10; // ADD ####
						mem[1] = 8'h34;
						mem[2] = 8'h12;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h5678;
						step_opcode();
						if (cf_dut.reg_PC != (3 + 1) || cf_dut.reg_ACC != (16'h1234 + 16'h5678)) fail_code();
					end
				10: // ADDB #34
					begin
						mem[0] = 8'h18; // ADDB ##
						mem[1] = 8'h34;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h5678;
						step_opcode();
						if (cf_dut.reg_PC != (2 + 1) || cf_dut.reg_ACC != (16'h0034 + 16'h5678)) fail_code();
					end
				11: // SUB #1234
					begin
						mem[0] = 8'h20; // SUB ####
						mem[1] = 8'h34;
						mem[2] = 8'h12;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h5678;
						step_opcode();
						if (cf_dut.reg_PC != (3 + 1) || cf_dut.reg_ACC != (16'h5678 - 16'h1234)) fail_code();
					end
				12: // SUBB #34
					begin
						mem[0] = 8'h28; // SUBB ##
						mem[1] = 8'h34;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h5678;
						step_opcode();
						if (cf_dut.reg_PC != (2 + 1) || cf_dut.reg_ACC != (16'h5678 - 16'h0034)) fail_code();
					end
				13: // MUL #1234
					begin
						mem[0] = 8'h30; // ADD ####
						mem[1] = 8'h34;
						mem[2] = 8'h12;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h5678;
						step_opcode();
						if (cf_dut.reg_PC != (3 + 1) || {cf_dut.reg_alt, cf_dut.reg_ACC} != (32'h1234 * 32'h5678)) fail_code();
					end
				14: // MULB #34
					begin
						mem[0] = 8'h38; // ADDB ##
						mem[1] = 8'h34;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h5678;
						step_opcode();
						if (cf_dut.reg_PC != (2 + 1) || {cf_dut.reg_alt, cf_dut.reg_ACC} != (32'h0034 * 32'h5678)) fail_code();
					end
				15: // DIV #101
					begin
						mem[0] = 8'h40; // DIV ####
						mem[1] = 8'h01;
						mem[2] = 8'h01;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h5678;
						step_opcode();
						if (cf_dut.reg_PC != (3 + 1) || 16'h5678 != (16'h0101 * cf_dut.reg_ACC + cf_dut.reg_alt)) fail_code();
					end
				16: // DIVB #11
					begin
						mem[0] = 8'h48; // DIVB ##
						mem[1] = 8'h11;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h5678;
						step_opcode();
						if (cf_dut.reg_PC != (2 + 1) || 16'h5678 != (16'h0011 * cf_dut.reg_ACC + cf_dut.reg_alt)) fail_code();
					end
				17: // AND #1234
					begin
						mem[0] = 8'h50; // AND ####
						mem[1] = 8'h34;
						mem[2] = 8'h12;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h5678;
						step_opcode();
						if (cf_dut.reg_PC != (3 + 1) || cf_dut.reg_ACC != (16'h5678 & 16'h1234)) fail_code();
					end
				18: // ANDB #34
					begin
						mem[0] = 8'h58; // ANDB ##
						mem[1] = 8'h34;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h5678;
						step_opcode();
						if (cf_dut.reg_PC != (2 + 1) || cf_dut.reg_ACC != (16'h5678 & 16'h0034)) fail_code();
					end
				18: // OR #1234
					begin
						mem[0] = 8'h60; // OR ####
						mem[1] = 8'h34;
						mem[2] = 8'h12;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h5678;
						step_opcode();
						if (cf_dut.reg_PC != (3 + 1) || cf_dut.reg_ACC != (16'h5678 | 16'h1234)) fail_code();
					end
				19: // ORB #34
					begin
						mem[0] = 8'h68; // ORB ##
						mem[1] = 8'h34;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h5678;
						step_opcode();
						if (cf_dut.reg_PC != (2 + 1) || cf_dut.reg_ACC != (16'h5678 | 16'h0034)) fail_code();
					end
				20: // XOR #1234
					begin
						mem[0] = 8'h70; // XOR ####
						mem[1] = 8'h34;
						mem[2] = 8'h12;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h5678;
						step_opcode();
						if (cf_dut.reg_PC != (3 + 1) || cf_dut.reg_ACC != (16'h5678 ^ 16'h1234)) fail_code();
					end
				21: // XORB #34
					begin
						mem[0] = 8'h78; // XORB ##
						mem[1] = 8'h34;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h5678;
						step_opcode();
						if (cf_dut.reg_PC != (2 + 1) || cf_dut.reg_ACC != (16'h5678 ^ 16'h0034)) fail_code();
					end
					
				22: // CMP #5678
					begin
						mem[0] = 8'h80; // CMP ####
						mem[1] = 8'h78;
						mem[2] = 8'h56;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h5678;
						step_opcode();
						if (cf_dut.reg_PC != (3 + 1) || cf_dut.reg_ACC != 1) fail_code();
					end
				23: // CMPB #78
					begin
						mem[0] = 8'h88; // CMPB ##
						mem[1] = 8'h34;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h5678;
						step_opcode();
						if (cf_dut.reg_PC != (2 + 1) || cf_dut.reg_ACC != 0) fail_code();
					end
				24: // LDI #1234
					begin
						mem[0] = 8'h90; // LDI ####
						mem[1] = 8'h34;
						mem[2] = 8'h12;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != (3 + 1) || cf_dut.reg_INDEX != 16'h1234) fail_code();
					end
				25: // LEAI 5678
					begin
						mem[0] = 8'h98 + 8'h01; // LEAI dddd
						mem[1] = 8'h78;
						mem[2] = 8'h56;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != (3 + 1) || cf_dut.reg_INDEX != 16'h5678) fail_code();
					end
				26: // LEAI I
					begin
						mem[0] = 8'h98 + 8'h02; // LEAI I
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_INDEX = 16'h789A;
						step_opcode();
						if (cf_dut.reg_PC != (1 + 1) || cf_dut.reg_INDEX != 16'h789A) fail_code();
					end
				27: // LEAI n,I
					begin
						mem[0] = 8'h98 + 8'h03; // LEAI n,I
						mem[1] = 8'h33;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_INDEX = 16'h789A;
						step_opcode();
						if (cf_dut.reg_PC != (2 + 1) || cf_dut.reg_INDEX != (16'h789A + 16'h0033)) fail_code();
					end
				28: // LEAI n,S
					begin
						mem[0] = 8'h98 + 8'h04; // LEAI n,S
						mem[1] = 8'h44;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_SP = 16'h4321;
						step_opcode();
						if (cf_dut.reg_PC != (2 + 1) || cf_dut.reg_INDEX != (16'h4321 + 16'h0044)) fail_code();
					end
				29: // LEAI [S+]
					begin
						mem[0] = 8'h98 + 8'h06; // LEAI [S+]
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_SP = 16'h0100;
						step_opcode();
						if (cf_dut.reg_PC != (1 + 1) || cf_dut.reg_INDEX != (16'h0102)) fail_code();
					end
				30: // LEAI [S]
					begin
						mem[0] = 8'h98 + 8'h07; // LEAI [S]
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_SP = 16'h0100;
						step_opcode();
						if (cf_dut.reg_PC != (1 + 1) || cf_dut.reg_INDEX != (16'h0100)) fail_code();
					end
					
//         [S+]  x6        Indirect through TOS (remove)
//         [S]   x7        Indirect through TOS (leave on stack)

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
