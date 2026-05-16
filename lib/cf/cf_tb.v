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
				if (mem_io_flag && mem_addr[7:0] != 8'h10) begin
					// we only support writing the value 91h to port 23h, and we read 8Bh from port 97h
					if (mem_wr_en && (mem_addr[7:0] != 8'h23 || mem_data_in[7:0] != 8'h91)) begin
						$display("Invalid I/O write of %x to port %x", mem_data_in[7:0], mem_addr[7:0]);
						$fatal;
					end
					if (!mem_wr_en) begin
						if (mem_addr[7:0] != 8'h97) begin
							$display("Invalid I/O read from port %x", mem_addr[7:0]);
							$fatal;
						end
						mem_data_out <= {8'h00, 8'h8B};
					end
				end else begin
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
	
	cf_cpu #(.TOP_VER(8'h11)) cf_dut(
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
						if (cf_dut.reg_PC != (1 + 1) || cf_dut.reg_INDEX != (16'h0100)) fail_code();
					end
				30: // LEAI [S]
					begin
						mem[0] = 8'h98 + 8'h07; // LEAI [S]
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_SP = 16'h0102;
						step_opcode();
						if (cf_dut.reg_PC != (1 + 1) || cf_dut.reg_INDEX != (16'h0100)) fail_code();
					end
				31: // ST 100
					begin
						mem[0] = 8'hA1;
						mem[1] = 8'h00;
						mem[2] = 8'h01;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h1234;
						step_opcode();
						if (cf_dut.reg_PC != (2 + 1) || mem[256] != 8'h34 || mem[257] != 8'h12) fail_code();
					end
				32: // STB 100
					begin
						mem[0] = 8'hA9;
						mem[1] = 8'h00;
						mem[2] = 8'h01;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h0058;
						step_opcode();
						if (cf_dut.reg_PC != (2 + 1) || mem[256] != 8'h58 || mem[257] != 8'h12) fail_code();
					end
				33: // STI 100
					begin
						mem[0] = 8'hB1;
						mem[1] = 8'h00;
						mem[2] = 8'h01;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_INDEX = 16'h7898;
						step_opcode();
						if (cf_dut.reg_PC != (2 + 1) || mem[256] != 8'h98 || mem[257] != 8'h78) fail_code();
					end
				34: // SHR ##
					begin
						mem[0] = 8'hB8;
						mem[1] = 8'h0B;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'hFFFF;
						step_opcode();
						if (cf_dut.reg_PC != (2 + 1) || cf_dut.reg_ACC != (16'hFFFF >> 11)) fail_code();
					end
				35: // SHL 100
					begin
						mem[0] = 8'hC1;
						mem[1] = 8'h00;
						mem[2] = 8'h01;
						mem[256] = 7;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h0001;
						step_opcode();
						if (cf_dut.reg_PC != (3 + 1) || cf_dut.reg_ACC != (16'h0001 << 7)) fail_code();
					end
				36: // setup compare we'll compare 0xFFFF to 1 which should be LT if signed and GT if unsigned
					begin
						mem[0] = 8'h80; // CMP ####
						mem[1] = 8'h01;
						mem[2] = 8'h00;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'hFFFF; // FFFF cmp 0001
						step_opcode();
						
						// now let's execute comparison opcodes
						mem[0] = 8'hC8; // LT
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'hFFFF; // dummy value
						step_opcode();
						if (cf_dut.reg_PC != (1 + 1) || cf_dut.reg_ACC != 1) fail_code(); // should be signed less than

						mem[0] = 8'hCA; // GT
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'hFFFF; // dummy value
						step_opcode();
						if (cf_dut.reg_PC != (1 + 1) || cf_dut.reg_ACC != 0) fail_code(); // should be not signed greater than

						mem[0] = 8'hCC; // ULT
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'hFFFF; // dummy value
						step_opcode();
						if (cf_dut.reg_PC != (1 + 1) || cf_dut.reg_ACC != 0) fail_code(); // should not be unsigned less than

						mem[0] = 8'hCE; // UGT
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'hFFFF; // dummy value
						step_opcode();
						if (cf_dut.reg_PC != (1 + 1) || cf_dut.reg_ACC != 1) fail_code(); // should be unsigned greater than						
					end
				37: // JMP aaaa
					begin
						mem[0] = 8'hD0; // JMP aaaa
						mem[1] = 8'h5E;
						mem[2] = 8'h73;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 16'h735E) fail_code();
					end
				38: // JZ aaaa
					begin
						mem[0] = 8'hD1; // JZ aaaa
						mem[1] = 8'h11;
						mem[2] = 8'h22;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 0;
						step_opcode();
						if (cf_dut.reg_PC != 16'h2211) fail_code();
						mem[0] = 8'hD1; // JZ aaaa
						mem[1] = 8'h11;
						mem[2] = 8'h22;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 1;
						step_opcode();
						if (cf_dut.reg_PC != 16'h3) fail_code();
					end
				39: // JNZ aaaa
					begin
						mem[0] = 8'hD2; // JNZ aaaa
						mem[1] = 8'h11;
						mem[2] = 8'h22;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 0;
						step_opcode();
						if (cf_dut.reg_PC != 16'h3) fail_code();
						mem[0] = 8'hD2; // JNZ aaaa
						mem[1] = 8'h11;
						mem[2] = 8'h22;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 1;
						step_opcode();
						if (cf_dut.reg_PC != 16'h2211) fail_code();
					end
				40: // SJMP rr
					begin
						mem[16'h0100] = 8'hD3; // SJMP rr
						mem[16'h0101] = 8'hFF; // -1
						cf_dut.reg_PC = 16'h0100;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 16'h101) fail_code(); // should jump back 1 byte from 102 which is just after the SJMP
					end
				41: // SJZ rr
					begin
						mem[16'h0100] = 8'hD4; // SJZ rr
						mem[16'h0101] = 8'hFF; // -1
						cf_dut.reg_PC = 16'h0100;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 0;
						step_opcode();
						if (cf_dut.reg_PC != 16'h101) fail_code(); // should jump back 1 byte from 102 which is just after the SJZ

						mem[16'h0100] = 8'hD4; // SJZ rr
						mem[16'h0101] = 8'hFF; // -1
						cf_dut.reg_PC = 16'h0100;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 1;
						step_opcode();
						if (cf_dut.reg_PC != 16'h102) fail_code(); // should not jump back 1 byte from 102 which is just after the SJZ
					end
				42: // SJNZ rr
					begin
						mem[16'h0100] = 8'hD5; // SJNZ rr
						mem[16'h0101] = 8'hFF; // -1
						cf_dut.reg_PC = 16'h0100;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 1;
						step_opcode();
						if (cf_dut.reg_PC != 16'h101) fail_code(); // should jump back 1 byte from 102 which is just after the SJNZ

						mem[16'h0100] = 8'hD5; // SJNZ rr
						mem[16'h0101] = 8'hFF; // -1
						cf_dut.reg_PC = 16'h0100;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 0;
						step_opcode();
						if (cf_dut.reg_PC != 16'h102) fail_code(); // should not jump back 1 byte from 102 which is just after the SJNZ
					end
				43: // IJMP
					begin
						mem[16'h0100] = 8'hD6; // IJMP
						cf_dut.reg_PC = 16'h0100;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h5432;
						step_opcode();
						if (cf_dut.reg_PC != 16'h5433) fail_code();
					end
				44: // SWITCH
					begin
						// setup table at 0100: {200h, 0}, {300h, 1}, {0, 400h}
						mem[16'h0100] = 8'h00;
						mem[16'h0101] = 8'h02;
						mem[16'h0102] = 8'h00;
						mem[16'h0103] = 8'h00;
						
						mem[16'h0104] = 8'h00;
						mem[16'h0105] = 8'h03;
						mem[16'h0106] = 8'h01;
						mem[16'h0107] = 8'h00;
						
						mem[16'h0108] = 8'h00;
						mem[16'h0109] = 8'h00;
						mem[16'h010A] = 8'h00;
						mem[16'h010B] = 8'h04;
						
						// run three tests
						// case 0
						mem[0] = 8'hD7;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h0;
						cf_dut.reg_INDEX = 16'h0100;
						step_opcode();
						if (cf_dut.reg_PC != 16'h0200) fail_code();
						// case 1
						mem[0] = 8'hD7;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h1;
						cf_dut.reg_INDEX = 16'h0100;
						step_opcode();
						if (cf_dut.reg_PC != 16'h0300) fail_code();
						// default
						mem[0] = 8'hD7;
						cf_dut.reg_PC = 0;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'h2;
						cf_dut.reg_INDEX = 16'h0100;
						step_opcode();
						if (cf_dut.reg_PC != 16'h0400) fail_code();
					end
				45: // CALL and RET
					begin
						mem[16'h0000] = 8'hD8; // CALL 200h
						mem[16'h0001] = 8'h00;
						mem[16'h0002] = 8'h02;
						cf_dut.reg_PC = 16'h0000;
						cf_dut.reg_SP = 16'h0100;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 16'h0200 || cf_dut.reg_SP != 16'h00FE || mem[16'h00FE] != 8'h03 || mem[16'h00FF] != 8'h00) fail_code();
						// RET
						mem[16'h0200] = 8'hD9;
						cf_dut.reg_PC = 16'h0200;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 16'h0003 || cf_dut.reg_SP != 16'h0100) fail_code();
					end
				46: // ALLOC and FREE
					begin
						mem[16'h0000] = 8'hDA;
						mem[16'h0001] = 8'h20; // ALLOC 20h
						cf_dut.reg_PC = 16'h0000;
						cf_dut.reg_SP = 16'h0100;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 2 || cf_dut.reg_SP != (16'h0100 - 16'h0020)) fail_code();
						mem[16'h0000] = 8'hDB;
						mem[16'h0001] = 8'h20; // FREE 20h
						cf_dut.reg_PC = 16'h0000;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 2 || cf_dut.reg_SP != (16'h0100)) fail_code();
					end
				47: // PUSHA
					begin
						mem[16'h0000] = 8'hDC;
						cf_dut.reg_PC = 16'h0000;
						cf_dut.reg_SP = 16'h0100;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_ACC = 16'hABCD;
						step_opcode();
						if (cf_dut.reg_PC != 1 || cf_dut.reg_SP != (16'h0100 - 16'h0002) || mem[16'hFE] != 8'hCD || mem[16'hFF] != 8'hAB) fail_code();
					end
				48: // PUSHI
					begin
						mem[16'h0000] = 8'hDD;
						cf_dut.reg_PC = 16'h0000;
						cf_dut.reg_SP = 16'h0100;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						cf_dut.reg_INDEX = 16'hEF01;
						step_opcode();
						if (cf_dut.reg_PC != 1 || cf_dut.reg_SP != (16'h0100 - 16'h0002) || mem[16'hFE] != 8'h01 || mem[16'hFF] != 8'hEF) fail_code();
					end
				49: // TAS and TSA
					begin
						mem[16'h0000] = 8'hDE; // TAS
						cf_dut.reg_PC = 16'h0000;
						cf_dut.reg_SP = 16'h0100;
						cf_dut.reg_ACC = 16'hEF01;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 2 || cf_dut.reg_SP != 16'hEF01) fail_code();
						mem[16'h0000] = 8'hDF; // TSA
						cf_dut.reg_PC = 16'h0000;
						cf_dut.reg_ACC = 16'h0000;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 2 || cf_dut.reg_ACC != 16'hEF01) fail_code();
					end
				50: // CLR, COM, NEG, NOT, INC, DEC
					begin
						mem[16'h0000] = 8'hE0; // CLR
						cf_dut.reg_PC = 16'h0000;
						cf_dut.reg_ACC = 16'hEF01;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 2 || cf_dut.reg_ACC != 16'h0000) fail_code();

						mem[16'h0000] = 8'hE1; // COM
						cf_dut.reg_PC = 16'h0000;
						cf_dut.reg_ACC = 16'h5AA5;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 2 || cf_dut.reg_ACC != ~16'h5AA5) fail_code();
						
						mem[16'h0000] = 8'hE2; // NEG
						cf_dut.reg_PC = 16'h0000;
						cf_dut.reg_ACC = 16'h0001;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 2 || cf_dut.reg_ACC != 16'hFFFF) fail_code();

						mem[16'h0000] = 8'hE3; // NOT
						cf_dut.reg_PC = 16'h0000;
						cf_dut.reg_ACC = 16'h0000;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 2 || cf_dut.reg_ACC != 16'h0001) fail_code();

						mem[16'h0000] = 8'hE4; // INC
						cf_dut.reg_PC = 16'h0000;
						cf_dut.reg_ACC = 16'h1122;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 2 || cf_dut.reg_ACC != 16'h1123) fail_code();

						mem[16'h0000] = 8'hE5; // DEC
						cf_dut.reg_PC = 16'h0000;
						cf_dut.reg_ACC = 16'h4443;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 2 || cf_dut.reg_ACC != 16'h4442) fail_code();
					end
				51: // TAI, TIA, ADAI, ALT
					begin
						mem[16'h0000] = 8'hE6; // TAI
						cf_dut.reg_PC = 16'h0000;
						cf_dut.reg_ACC = 16'h4443;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 2 || cf_dut.reg_INDEX != 16'h4443) fail_code();
						mem[16'h0000] = 8'hE7; // TIA
						cf_dut.reg_PC = 16'h0000;
						cf_dut.reg_INDEX = 16'h3278;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 2 || cf_dut.reg_ACC != 16'h3278) fail_code();
						mem[16'h0000] = 8'hE8; // ADAI
						cf_dut.reg_PC = 16'h0000;
						cf_dut.reg_ACC = 16'h7777;
						cf_dut.reg_INDEX = 16'h8888;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 2 || cf_dut.reg_INDEX != (16'h7777 + 16'h8888)) fail_code();
						mem[16'h0000] = 8'hE9; // ALT
						cf_dut.reg_PC = 16'h0000;
						cf_dut.reg_ACC = 16'h3333;
						cf_dut.reg_alt = 16'h2222;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 2 || cf_dut.reg_ACC != 16'h2222) fail_code();
					end
				52: // OUT, IN
					begin
						// to test the mechanism we only support very specific I/O access in this bench
						// we only support writing the value 91h to port 23h, and we read 8Bh from port 97h
						mem[16'h0000] = 8'hEA; // OUT pp
						mem[16'h0001] = 8'h23; // port 23h
						cf_dut.reg_PC = 16'h0000;
						cf_dut.reg_ACC = 16'h0091;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 2) fail_code();
						mem[16'h0000] = 8'hEB; // IN pp
						mem[16'h0001] = 8'h97; // port 97h
						cf_dut.reg_PC = 16'h0000;
						cf_dut.reg_ACC = 16'h0091;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 2 || cf_dut.reg_ACC != 16'h8B) fail_code();
					end
				53: // CPUVER (opcode 0xED)
					begin
						mem[16'h0000] = 8'hED; // CPUVER
						mem[16'h0001] = 8'hE4; // INC (the way we single step is stupid so we force a single byte opcode here .... TODO: fix)
						cf_dut.reg_PC = 16'h0000;
						cf_dut.reg_ACC = 16'hFFFF;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						step_opcode();
						if (cf_dut.reg_PC != 3 || cf_dut.reg_ACC != (16'h1101 + 1)) fail_code();
					end
/*
				54: // boot rom test
					begin
						$readmemh("boot_test_sim.hex", mem);
						cf_dut.reg_PC = 16'hF000;
						cf_dut.fsm_state = 0;
						cf_dut.bus_enable = 0;
						repeat(1024) @(posedge clk);
					end
*/
			endcase
		end
		$display("Ran %d opcodes in %d cycles (%d per inst)", inst_cnt, cycles, (cycles * 100) / inst_cnt); 

		$finish;
	end
	
	task fail_code();
		begin
			$display("Failed test #%d", i);
			$display("PC=%x ACC=%x INDEX=%x SP=%x m1=%x m2=%x", cf_dut.reg_PC, cf_dut.reg_ACC, cf_dut.reg_INDEX, cf_dut.reg_SP, mem[256], mem[257]);
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
