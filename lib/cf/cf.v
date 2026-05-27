/* C-FLEA CPU Design */

// version, read by using opcode 0xED which puts this in ACC
`define cf_core_version 8'h05

`default_nettype none
`timescale 1ns/1ps

module cf_cpu #(
	parameter TOP_VER     = 8'h00,
    parameter BOOT_VECTOR = 16'hF000,
    parameter USE_BARREL  = 1           // barrel shifter results in faster shr/shl but at cost of about 36 logic cells and hit to Fmax by about 2-3%
)(
	input wire clk,
	input wire rst_n,
	
	// bus
	output reg [16:0] bus_address,		// 0..FFFF CODE, 10000..1FFFF DATA (can be merged to form a 64K space)
	output reg bus_wr_en,				// write enable
	output reg bus_io_flag,				// I/O bus activity (e.g. inp/outp)
	output reg bus_burst,				// high == 16 bit transfer
	output reg [15:0] bus_data_in,		// input
	output reg bus_enable,				// tell the bus we're good to go
	
	input wire bus_ready,				// bus tells us it's ready
	input wire [15:0] bus_data_out		// output
);

	// ISA state
	reg [15:0] reg_ACC;
	reg [15:0] reg_INDEX;
	reg [15:0] reg_SP;
	reg [15:0] reg_PC;
	reg [7:0]  reg_flags;  				// signed{LT, GT}, unsigned{LT, GT}, EQ
	reg [15:0] reg_alt;
	reg [7:0]  cur_opcode;				// opcode byte
	reg [15:0] reg_operand;				// the operand
	reg 	   reg_operand_16;			// is it a 16-bit operand?
	reg [15:0] switch_table_addr;		// current address of switch table
	reg [15:0] switch_addr;				// current switch address (to pair with value)
    reg [15:0] cycle_count;             // cycle count can be read+reset with opcode 0xEE
	
	localparam
		FLAG_SLT = 0,
		FLAG_SGT = 1,
		FLAG_ULT = 2,
		FLAG_UGT = 3,
		FLAG_EQ  = 4;
	
	// FSM state
	reg [3:0]  fsm_state;

	localparam
		FSM_FETCH_OPCODE                  = 0,
		FSM_FETCH_ALU_OPERAND_00_97       = 1,		// handle opcodes upto 0x97 (but also include SHR/SHL)
		FSM_FETCH_ALU_OPERAND2_00_97      = 2,
		FSM_EXECUTE_ALU_OPCODE_00_97      = 3,

		FSM_FETCH_ALU_OPERAND_98_B7       = 4,		// store
		FSM_FETCH_ALU_OPERAND_98_B7_STORE = 5,  	// back half of store
		
		FSM_EXECUTE_OPCODE_C8_CF          = 6,		// directly execute C8...CF

		FSM_EXECUTE_OPERAND_D0_D9         = 7,		// directly execute or prepare D0..D9
		FSM_OPCODE_D8_1                   = 8,

		FSM_EXECUTE_OPERAND_DA_DF         = 9,		// directly execute or prepare DA..DF

		FSM_EXECUTE_OPERAND_E0_EC         = 10,		// directly prepare or execute E0..EC

		FSM_EXECUTE_OPERAND2_EA_EB        = 11,		// handle EA and EB (I/O)
		
		FSM_SWITCH_LOAD_ADDR              = 12,		// load current 
		FSM_SWITCH_LOAD_VALUE		      = 13;

	// used to detect when we're starting a new opcode
	reg cf_start_fetch;
	
	// divider
	reg [15:0] sd_num;
	reg [15:0] sd_denom;
	reg sd_valid;
	wire sd_ready;
	wire [15:0] sd_quotient;
	wire [15:0] sd_remainder;
	
	serial_divide divider(
		.clk(clk),
		.rst_n(rst_n),
		.num(sd_num), .denom(sd_denom), .valid(sd_valid),
		.ready(sd_ready), .quotient(sd_quotient), .remainder(sd_remainder));
		
	always @(posedge clk) begin
		if (!rst_n) begin
			// reset all registers
			bus_address  <= 0;
			bus_wr_en    <= 0;
			bus_io_flag  <= 0;
			bus_burst    <= 0;
			bus_data_in  <= 0;
			bus_enable   <= 0;
			reg_ACC		 <= 0;
			reg_alt      <= 0;
			reg_INDEX    <= 0;
			reg_SP       <= 0;
			reg_PC       <= BOOT_VECTOR;
			reg_flags    <= 0;
			cur_opcode   <= 0;
			reg_operand  <= 0;
			reg_operand_16 <= 0;
			fsm_state    <= FSM_FETCH_OPCODE;
			sd_valid	 <= 0;
			sd_num       <= 0;
			sd_denom     <= 0;
			switch_addr  <= 0;
			switch_table_addr <= 0;
			cf_start_fetch <= 0;
            cycle_count  <= 0;
		end else begin
			cf_start_fetch <= 1'b0;
            cycle_count <= cycle_count + 1'b1;
			case(fsm_state)
				// Initial state where we fetch the next opcode byte
				FSM_FETCH_OPCODE:
					begin
						// fetch next opcode byte
						if (!bus_enable) begin
							cf_start_fetch <= 1'b1;
							bus_enable  <= 1'b1;
							bus_wr_en   <= 1'b0;
							bus_io_flag <= 1'b0;
							bus_burst   <= 1'b0;
							bus_address <= {1'b0, reg_PC};
						end
						if (bus_enable && bus_ready) begin
							reg_PC      <= reg_PC + 1'b1;
							cur_opcode  <= bus_data_out[7:0];
							bus_enable  <= 1'b0;
							if (bus_data_out[7:0] <= 8'h97) begin
								// generic ALU ops that use one of the 8 operand formats
								// so the goal here is to first load an "operand" to pair with
								// an ALU op like ADD, SUB, etc...
								fsm_state      <= FSM_FETCH_ALU_OPERAND_00_97;
								reg_operand_16 <= ~bus_data_out[3];
							end else if (bus_data_out[7:0] >= 8'h98 && bus_data_out[7:0] <= 8'hB7) begin
								// ST (store) ops (LEAI, ST, STB, STI)
								// the goal here is to load an operand which says where to store ACC or INC
								fsm_state 		<= FSM_FETCH_ALU_OPERAND_98_B7;
								reg_operand_16 	<= (bus_data_out[7:4] == 4'hB) ? 1'b1 : ~bus_data_out[3]; // 16-bit if STI or ST, 8-bit for STB
							end else if (bus_data_out[7:0] >= 8'hB8 && bus_data_out[7:0] <= 8'hC7) begin
								// SHR and SHL: fall back to generic ops but force operand to 8 bit
								fsm_state		<= FSM_FETCH_ALU_OPERAND_00_97;
								reg_operand_16  <= 0;
							end else if (bus_data_out[7:0] >= 8'hC8 && bus_data_out[7:0] <= 8'hCF) begin
								// LT/LE...UGT/UGE
								fsm_state <= FSM_EXECUTE_OPCODE_C8_CF;
							end else if (bus_data_out[7:0] >= 8'hD0 && bus_data_out[7:0] <= 8'hD9) begin
								fsm_state <= FSM_EXECUTE_OPERAND_D0_D9;
							end else if (bus_data_out[7:0] >= 8'hDA && bus_data_out[7:0] <= 8'hDF) begin
								fsm_state <= FSM_EXECUTE_OPERAND_DA_DF;
							end else if (bus_data_out[7:0] >= 8'hE0 && bus_data_out[7:0] <= 8'hEC) begin
								fsm_state <= FSM_EXECUTE_OPERAND_E0_EC;
							end else if (bus_data_out[7:0] == 8'hED) begin
								reg_ACC   <= {TOP_VER, `cf_core_version};
							end else if (bus_data_out[7:0] == 8'hEE) begin
								reg_ACC     <= cycle_count;
                                cycle_count <= 16'b0;
							end else begin
								// unhandled opcodes just make us fetch the next...
								fsm_state <= fsm_state;
							end
						end
					end
					
				// Fetch the 1-2 byte operand that goes with ALU (and SHR/SHL) opcodes
				FSM_FETCH_ALU_OPERAND_00_97:
					// start of decoding one of the 8 operand modes
					begin
						// first half to either read an immediate or address of the operand
						if (!bus_enable) begin
							bus_enable  <= 1'b1;
							case(cur_opcode[2:0])
								0: // #n x0 ii(ii)							// immediate 8/16 bit
									begin
										bus_address <= {1'b0, reg_PC};
										reg_PC 		<= reg_PC + 1'b1 + reg_operand_16;
										bus_burst   <= reg_operand_16;		// 8 or 16 bit immediate
									end
								1: // aaaa x1 dd dd							// load from data memory		
									begin
										bus_address <= {1'b0, reg_PC};		// load address from code memory first
										reg_PC 		<= reg_PC + 16'd2;
										bus_burst   <= 1'b1;
									end
								2: // I x2 I								// load directly from I
									begin
										bus_address <= {1'b1, reg_INDEX};	// load from data memory
										bus_burst   <= reg_operand_16;		// load 8 or 16 bit from [I]
									end
								3: // n,I x3 oo								// load from INDEX+nn
									begin
										bus_address <= {1'b0, reg_PC};
										reg_PC 		<= reg_PC + 1'b1;
										bus_burst   <= 0;					// offset is only 8 bits 
									end
								4: // n,S x4 oo								// load from SP+nn
									begin
										bus_address <= {1'b0, reg_PC};
										reg_PC 		<= reg_PC + 1'b1;
										bus_burst   <= 0;					// offset is only 8 bits 
									end
								5: // S+ x5									// load from S then increment S
									begin
										bus_address <= {1'b1, reg_SP};		// load from data memory
										bus_burst   <= 1'b1;				// stack always works in 16-bits
										reg_SP      <= reg_SP + 16'd2;		// increment after
									end
								6: // [S+] x6								// load from [S] then increment S
									begin
										bus_address <= {1'b1, reg_SP};		// load from data memory
										bus_burst   <= 1'b1;				// stack always works in 16-bits
										reg_SP      <= reg_SP + 16'd2;		// increment after
									end
								7: // [S] x7								// load from [S]
									begin
										bus_address <= {1'b1, reg_SP};		// load from data memory
										bus_burst   <= 1'b1;				// stack always works in 16-bits
									end
							endcase
						end
						
						// second half we either have the operand (immediate/index)
						// or we have the address to load the operand from
						if (bus_enable && bus_ready) begin					// back half of FETCH for 00..97
							// second half of initial operand fetch.  In some cases we're done
							// in other cases what we've loaded so far is the address we need
							// to actually fetch the operand.
							bus_enable <= 1'b0;
							case(cur_opcode[2:0])
								0: // #n x0 ii(ii)
									begin
										// immediate we have the operand
										reg_operand <= bus_data_out;
										fsm_state   <= FSM_EXECUTE_ALU_OPCODE_00_97;
									end
								1: // aaaa x1 dd dd
									begin
										// we read the address to read from now we have to actually read it 
										bus_address <= {1'b1, bus_data_out};
										bus_burst   <= reg_operand_16;
										fsm_state   <= FSM_FETCH_ALU_OPERAND2_00_97;
									end
								2: // I x2 I
									begin
										// we've read [INDEX]
										reg_operand <= bus_data_out;
										fsm_state   <= FSM_EXECUTE_ALU_OPCODE_00_97;
									end
								3: // n,I x3 oo
									begin
										bus_address <= {1'b1, reg_INDEX + bus_data_out};
										bus_burst   <= reg_operand_16;
										fsm_state   <= FSM_FETCH_ALU_OPERAND2_00_97;
									end
								4: // n,S x4 oo
									begin
										bus_address <= {1'b1, reg_SP + bus_data_out};
										bus_burst   <= reg_operand_16;
										fsm_state   <= FSM_FETCH_ALU_OPERAND2_00_97;
									end
								5: // S+ x5
									begin
										// popped the operand off the stack
										reg_operand <= bus_data_out;
										fsm_state   <= FSM_EXECUTE_ALU_OPCODE_00_97;
									end
								6: // [S+] x6
									begin
										bus_address <= {1'b1, bus_data_out};
										bus_burst   <= reg_operand_16;
										fsm_state   <= FSM_FETCH_ALU_OPERAND2_00_97;
									end
								7: // [S] x7
									begin
										bus_address <= {1'b1, bus_data_out};
										bus_burst   <= reg_operand_16;
										fsm_state   <= FSM_FETCH_ALU_OPERAND2_00_97;
									end
							endcase
						end
					end
				// 2nd FSM state for fetching operands for ALU ops upto 0x97
				// This is called after we've loaded the address from the adjacent opcode bytes or off the stack
				// now we have a pointer so we have to load the reg_operand
				FSM_FETCH_ALU_OPERAND2_00_97:
					begin
						if (!bus_enable) begin
							// bus was otherwise programmed already we just need to enable it
							bus_enable  <= 1'b1;
						end else if (bus_enable && bus_ready) begin
							bus_enable  <= 1'b0;
							reg_operand <= bus_data_out;					// finally have the operand 
							fsm_state   <= FSM_EXECUTE_ALU_OPCODE_00_97;
						end
					end

				// execute opcodes upto byte 0x97 (also SHR/SHL)					
				FSM_EXECUTE_ALU_OPCODE_00_97:
					begin
						// we're done after this so we fetch
						fsm_state <= FSM_FETCH_OPCODE;
						bus_enable  <= 1'b1;
						bus_wr_en   <= 1'b0;
						bus_io_flag <= 1'b0;
						bus_burst   <= 1'b0;
						bus_address <= {1'b0, reg_PC};
						
						case(cur_opcode[7:4])
							4'h0: // LD/LDB
								begin
									reg_ACC <= reg_operand;
								end
							4'h1: // ADD/ADDB
								begin
									reg_ACC <= reg_ACC + reg_operand;
								end
							4'h2: // SUB/SUBB
								begin
									reg_ACC <= reg_ACC - reg_operand;
								end
							4'h3: // MUL/MULB
								begin
									{reg_alt,reg_ACC} <= reg_ACC * reg_operand;
								end
							4'h4: // DIV/DIVB
								begin
									fsm_state <= fsm_state;			// loop here until division is done
									bus_enable <= 1'b0;
									if (!sd_valid && !sd_ready) begin
										sd_num   <= reg_ACC;
										sd_denom <= reg_operand;
										sd_valid <= 1'b1;
									end
									if (sd_valid && sd_ready) begin
										fsm_state <= FSM_FETCH_OPCODE;
										bus_enable <= 1'b1;
										reg_ACC   <= sd_quotient;						// ACC gets quotient and we put remainder in ALT location
										reg_alt   <= sd_remainder;
										sd_valid  <= 1'b0;
									end
								end
							4'h5: // AND/ANDB
								begin
									reg_ACC <= reg_ACC & reg_operand;
								end
							4'h6: // OR/ORB
								begin
									reg_ACC <= reg_ACC | reg_operand;
								end
							4'h7: // XOR/XORB
								begin
									reg_ACC <= reg_ACC ^ reg_operand;
								end
							4'h8: // CMP/CMPB
								begin
									reg_flags[FLAG_EQ]  <= (reg_ACC == reg_operand) ? 1'b1 : 1'b0;
									reg_ACC             <= (reg_ACC == reg_operand) ? 16'd1 : 16'd0;
									if (reg_operand_16) begin
										// compare full 16 bits
										reg_flags[FLAG_SLT] <= ($signed(reg_ACC) < $signed(reg_operand)) ? 1'b1 : 1'b0;
										reg_flags[FLAG_SGT] <= ($signed(reg_ACC) > $signed(reg_operand)) ? 1'b1 : 1'b0;
									end else begin
										// compare only bottom 8 bits for CMPB
										reg_flags[FLAG_SLT] <= ($signed(reg_ACC[7:0]) < $signed(reg_operand[7:0])) ? 1'b1 : 1'b0;
										reg_flags[FLAG_SGT] <= ($signed(reg_ACC[7:0]) > $signed(reg_operand[7:0])) ? 1'b1 : 1'b0;
									end
									reg_flags[FLAG_ULT] <= (reg_ACC < reg_operand) ? 1'b1 : 1'b0;
									reg_flags[FLAG_UGT] <= (reg_ACC > reg_operand) ? 1'b1 : 1'b0;
								end
							4'h9: // LDI
								begin
									reg_INDEX <= reg_operand;
								end
							default:
								begin
									// SHR/SHL opcodes
									case(cur_opcode[7:3])
										5'h17: // SHR
											begin
                                                if (USE_BARREL == 1) begin
                                                    reg_ACC <= reg_ACC >> reg_operand;
                                                end else begin
                                                    if (reg_operand != 0) begin
                                                        reg_ACC 	<= {1'b0, reg_ACC[15:1]};
                                                        reg_operand <= reg_operand - 1'b1;
                                                        fsm_state 	<= fsm_state;
                                                    end
                                                end
                                            end
										5'h18: // SHL
											begin
                                                if (USE_BARREL == 1) begin
                                                    reg_ACC <= reg_ACC << reg_operand;
                                                end else begin
                                                    if (reg_operand != 0) begin
                                                        reg_ACC		<= {reg_ACC[14:0], 1'b0};
                                                        reg_operand <= reg_operand - 1'b1;
                                                        fsm_state   <= fsm_state;
                                                    end
                                                end
											end
										default: begin end
									endcase
								end
						endcase
					end

				// LEAI, ST, STB, and STI opcodes
				// Like 00..9F we have to resolve the operand address if any first
				FSM_FETCH_ALU_OPERAND_98_B7:								// handle ST (store) operand fetching
					begin
						// fetch the destination to store to
						if (!bus_enable) begin				// fetch the destination operand
							bus_enable  <= 1'b1;
							bus_wr_en   <= 1'b0;
							case(cur_opcode[2:0])
								1: // aaaa x1 dd dd							// load from data memory		
									begin
										bus_address <= {1'b0, reg_PC};		// load address from code memory first
										reg_PC 		<= reg_PC + 16'd2;
										bus_burst   <= 1'b1;
									end
								2: // I x2 I								// load directly from I
									begin
										bus_enable  <= 1'b0;
										bus_address <= {1'b0, reg_INDEX};
										bus_data_in <= (cur_opcode[7:4] == 4'hA) ? reg_ACC : reg_INDEX; // ST/STB or STI
										fsm_state   <= FSM_FETCH_ALU_OPERAND_98_B7_STORE;
										bus_burst   <= reg_operand_16;									// are we storing 16 or 8 bits
									end
								3: // n,I x3 oo								// load from INDEX+nn
									begin
										bus_address <= {1'b0, reg_PC};
										reg_PC 		<= reg_PC + 1'b1;
										bus_burst   <= 0;					// offset is only 8 bits 
									end
								4: // n,S x4 oo								// load from SP+nn
									begin
										bus_address <= {1'b0, reg_PC};
										reg_PC 		<= reg_PC + 1'b1;
										bus_burst   <= 0;					// offset is only 8 bits 
									end
								6: // [S+] x6								// load from [S] then increment S
									begin
										bus_address <= {1'b1, reg_SP};		// load from data memory
										if (cur_opcode[7:4] != 4'h9) begin  // don't move SP for LEAI?
											reg_SP <= reg_SP + 16'd2;
										end
										bus_burst   <= 1;					// 16 bits off the stack 
									end
								7: // [S] x7								// load from [S]
									begin
										bus_address <= {1'b1, reg_SP};		// load from data memory
										bus_burst   <= 1;					// 16 bits off the stack 
									end
								default: // NOTE: lockup
									begin end
							endcase
						end
						
						// we've loaded the address from memory 
						if (bus_enable && bus_ready) begin					// back half of store operand fetching
							bus_enable  <= 1'b0;
							fsm_state   <= FSM_FETCH_ALU_OPERAND_98_B7_STORE;
							bus_data_in <= (cur_opcode[7:4] == 4'hA) ? reg_ACC : reg_INDEX; // ST/STB or STI
							bus_burst   <= reg_operand_16;									// are we storing 16 or 8 bits
							case(cur_opcode[2:0])
								1: // aaaa x1 dd dd
									begin
										bus_address <= {1'b1, bus_data_out};
									end
								3: // n,I x3 oo
									begin
										bus_address <= {1'b1, bus_data_out + reg_INDEX };
									end
								4: // n,S x4 oo
									begin
										bus_address <= {1'b1, bus_data_out + reg_SP };
									end
								6: // [S+] x6
									begin
										bus_address <= {1'b1, bus_data_out };
									end
								7: // [S] x7
									begin
										bus_address <= {1'b1, bus_data_out };
									end
								default: begin end // NOTE: lockup
							endcase
						end
					end
				
				// back half of ST/STB/STI where we actually do the store.
				FSM_FETCH_ALU_OPERAND_98_B7_STORE:
					begin
						if (!bus_enable) begin
							if (cur_opcode[7:3] == 5'h13) begin // LEAI
								reg_INDEX <= bus_address[15:0];
								fsm_state <= FSM_FETCH_OPCODE;
							end else begin						// ST/STB/STI
								bus_wr_en  <= 1'b1;
								bus_enable <= 1'b1;
							end
						end
						if (bus_enable && bus_ready) begin
							bus_wr_en  <= 1'b0;
							bus_enable <= 1'b0;
							fsm_state  <= FSM_FETCH_OPCODE;
						end
					end
					
				FSM_EXECUTE_OPCODE_C8_CF: //LT/LE.../UGT/UGE
					begin
						fsm_state <= FSM_FETCH_OPCODE;
						bus_enable  <= 1'b1;
						bus_wr_en   <= 1'b0;
						bus_io_flag <= 1'b0;
						bus_burst   <= 1'b0;
						bus_address <= {1'b0, reg_PC };
						case(cur_opcode[3:0])
							4'h8: // LT
								reg_ACC <= { 15'b0, reg_flags[FLAG_SLT] };
							4'h9: // LE
								reg_ACC <= { 15'b0, reg_flags[FLAG_SLT] | reg_flags[FLAG_EQ] };
							4'hA: // GT
								reg_ACC <= { 15'b0, reg_flags[FLAG_SGT] };
							4'hB: // GE
								reg_ACC <= { 15'b0, reg_flags[FLAG_SGT] | reg_flags[FLAG_EQ] };
							4'hC: // ULT
								reg_ACC <= { 15'b0, reg_flags[FLAG_ULT] };
							4'hD: // ULE
								reg_ACC <= { 15'b0, reg_flags[FLAG_ULT] | reg_flags[FLAG_EQ] };
							4'hE: // UGT
								reg_ACC <= { 15'b0, reg_flags[FLAG_UGT] };
							4'hF: // UGE
								reg_ACC <= { 15'b0, reg_flags[FLAG_UGT] | reg_flags[FLAG_EQ] };
							default: begin end
						endcase
					end

				FSM_EXECUTE_OPERAND_D0_D9: // jumps
					begin
						if (!bus_enable) begin
							bus_enable  <= 1'b1;
							bus_wr_en   <= 1'b0;
							bus_io_flag <= 1'b0;
							case(cur_opcode[3:0])
								4'h0: // JMP aaaa
									begin
										bus_burst   <= 1'b1;
										bus_address <= {1'b0, reg_PC};
										reg_PC      <= reg_PC + 16'd2;
									end
								4'h1: // JZ aaaa
									begin
										bus_burst   <= 1'b1;
										bus_address <= {1'b0, reg_PC};
										reg_PC      <= reg_PC + 16'd2;
									end
								4'h2: // JNZ aaaa
									begin
										bus_burst   <= 1'b1;
										bus_address <= {1'b0, reg_PC};
										reg_PC      <= reg_PC + 16'd2;
									end
								4'h3: // SJMP rr
									begin
										bus_burst   <= 1'b0;
										bus_address <= {1'b0, reg_PC};
										reg_PC      <= reg_PC + 16'd1;
									end
								4'h4: // SJZ rr
									begin
										bus_burst   <= 1'b0;
										bus_address <= {1'b0, reg_PC};
										reg_PC      <= reg_PC + 16'd1;
									end
								4'h5: // SJNZ rr
									begin
										bus_burst   <= 1'b0;
										bus_address <= {1'b0, reg_PC};
										reg_PC      <= reg_PC + 16'd1;
									end
								4'h6: // IJMP
									begin
										bus_enable  <= 1'b0;
										reg_PC	    <= reg_ACC;
										fsm_state   <= FSM_FETCH_OPCODE;
									end
								4'h7: // SWITCH (ACC == value to test, INDEX == address of switch table (addr,value,addr2,value2,...,0,addrdefault)
									begin
										bus_enable        <= 1'b0;
										bus_address 	  <= {1'b0, reg_INDEX};
										bus_burst   	  <= 1'b1;
										switch_table_addr <= reg_INDEX;
										fsm_state   	  <= FSM_SWITCH_LOAD_ADDR;
									end
								4'h8: // CALL aaaa
									begin
										// read the call target
										bus_burst   <= 1'b1;
										bus_address <= {1'b0, reg_PC};
										reg_PC      <= reg_PC + 16'd2;
									end
								4'h9: // RET
									begin
										// read PC off stack
										bus_burst   <= 1'b1;
										bus_address <= {1'b1, reg_SP};
										reg_SP      <= reg_SP + 16'd2;
									end
								default: begin end
							endcase
						end
						if (bus_enable && bus_ready) begin							// back half of jumps
							bus_enable <= 1'b0;
							fsm_state  <= FSM_FETCH_OPCODE;
							case(cur_opcode[3:0])
								4'h0: // JMP aaaa
									begin
										reg_PC <= bus_data_out;
									end
								4'h1: // JZ aaaa
									begin
										if (reg_ACC == 0) begin
											reg_PC <= bus_data_out;
										end
									end
								4'h2: // JNZ aaaa
									begin
										if (reg_ACC != 0) begin
											reg_PC <= bus_data_out;
										end
									end
								4'h3: // SJMP rr
									begin
										reg_PC <= reg_PC + { {8{bus_data_out[7]}}, bus_data_out[7:0] };
									end
								4'h4: // SJZ rr
									begin
										if (reg_ACC == 0) begin
											reg_PC <= reg_PC + { {8{bus_data_out[7]}}, bus_data_out[7:0] };
										end					
									end
								4'h5: // SJNZ rr
									begin
										if (reg_ACC != 0) begin
											reg_PC <= reg_PC + { {8{bus_data_out[7]}}, bus_data_out[7:0] };
										end					
									end
								4'h8: // CALL aaaa
									begin
										fsm_state <= FSM_OPCODE_D8_1;			// jump to back half of CALL where we do the bus transaction
										// push PC onto stack
										bus_address <= {1'b1, reg_SP - 16'd2};
										bus_data_in <= reg_PC;
										bus_wr_en   <= 1'b1;
										bus_burst   <= 1'b1;
										reg_SP      <= reg_SP - 16'd2;
										reg_PC      <= bus_data_out;
									end
								4'h9: // RET
									begin
										reg_PC <= bus_data_out;
									end
								default: begin end // NOTE: lockup
							endcase
						end
					end
				FSM_OPCODE_D8_1: // back half of CALL where we push PC on the stack
					begin
						if (!bus_enable) begin
							// enable write to stack of PC
							bus_enable <= 1'b1;
						end else if (bus_enable && bus_ready) begin
							// PC was saved we can fetch the first opcode of the target.
							bus_enable <= 1'b0;
							fsm_state  <= FSM_FETCH_OPCODE;
						end
					end

				FSM_EXECUTE_OPERAND_DA_DF: // stack
					begin
						if (!bus_enable) begin
							bus_enable  <= 1'b1;
							bus_wr_en   <= 1'b0;
							bus_io_flag <= 1'b0;
							bus_burst   <= 1'b0;
							bus_address <= {1'b0, reg_PC };
							case(cur_opcode[3:0])
								4'hA: // ALLOC oo
									begin
										reg_PC      <= reg_PC + 1'b1;
									end
								4'hB: // FREE oo
									begin
										reg_PC      <= reg_PC + 1'b1;
									end
								4'hC: // PUSHA
									begin
										bus_wr_en    <= 1'b1;
										bus_burst    <= 1'b1;
										bus_address  <= {1'b1, reg_SP - 16'd2};
										bus_data_in  <= reg_ACC;
										reg_SP	     <= reg_SP - 16'd2;
									end
								4'hD: // PUSHI
									begin
										bus_wr_en    <= 1'b1;
										bus_burst    <= 1'b1;
										bus_address  <= {1'b1, reg_SP - 16'd2};
										bus_data_in  <= reg_INDEX;
										reg_SP	     <= reg_SP - 16'd2;
									end
								4'hE: // TAS
									begin
										reg_SP    <= reg_ACC;
										fsm_state <= FSM_FETCH_OPCODE;
									end
								4'hF: // TSA
									begin
										reg_ACC   <= reg_SP;
										fsm_state <= FSM_FETCH_OPCODE;
									end
								default: begin end // note: lockup
							endcase
						end
						if (bus_enable && bus_ready) begin
							bus_enable <= 1'b0;
							fsm_state  <= FSM_FETCH_OPCODE;
							case(cur_opcode[3:0])
								4'hA: // ALLOC oo
									begin
										reg_SP <= reg_SP - {8'b0, bus_data_out[7:0]};
									end
								4'hB: // FREE oo
									begin
										reg_SP <= reg_SP + {8'b0, bus_data_out[7:0]};
									end
								default: begin end
							endcase
						end
					end

				FSM_EXECUTE_OPERAND_E0_EC: // misc
					begin
						if (!bus_enable) begin
							// this is our first run into this FSM
							fsm_state <= FSM_FETCH_OPCODE;
							bus_enable  <= 1'b1;
							bus_wr_en   <= 1'b0;
							bus_io_flag <= 1'b0;
							bus_burst   <= 1'b0;
							bus_address <= {1'b0, reg_PC};
							case(cur_opcode[3:0])
								4'h0: // CLR
									reg_ACC <= 0;
								4'h1: // COM
									reg_ACC <= ~reg_ACC;
								4'h2: // NEG
									reg_ACC <= -reg_ACC;
								4'h3: // NOT
									reg_ACC <= reg_ACC == 0 ? 16'd1 : 16'd0;
								4'h4: // INC
									reg_ACC <= reg_ACC + 1'b1;
								4'h5: // DEC
									reg_ACC <= reg_ACC - 1'b1;
								4'h6: // TAI
									reg_INDEX <= reg_ACC;
								4'h7: // TIA
									reg_ACC <= reg_INDEX;
								4'h8: // ADAI
									reg_INDEX <= reg_INDEX + reg_ACC;
								4'h9: // ALT
									reg_ACC <= reg_alt;
								4'hA, 4'hB: // OUT/IN
									begin
										// fetch the port number after the opcode
										fsm_state   <= fsm_state;
										reg_PC      <= reg_PC + 1'b1;
									end
								default: begin end
							endcase
						end
						if (bus_enable && bus_ready) begin
							// we got the port number, now setup the I/O request
							bus_enable  <= 1'b0;
							bus_io_flag <= 1'b1;
							bus_address <= {1'b0, bus_data_out};
							bus_data_in <= reg_ACC;
							bus_wr_en   <= cur_opcode[3:0] == 4'hA ? 1'b1 : 1'b0;  // EA == out
							fsm_state   <= FSM_EXECUTE_OPERAND2_EA_EB;
						end
					end
				FSM_EXECUTE_OPERAND2_EA_EB:										   // issue I/O
					begin
						if (!bus_enable) begin
							// rest of bus was previously programmed
							bus_enable <= 1'b1;
						end else if (bus_enable && bus_ready) begin
							// I/O is complete deassert bus and go back to fetch
							if (cur_opcode == 8'hEB) begin							// EB == IN
								reg_ACC <= bus_data_out;
							end
							bus_enable  <= 1'b0;
							bus_io_flag <= 1'b0;
							fsm_state   <= FSM_FETCH_OPCODE;
						end
					end

				FSM_SWITCH_LOAD_ADDR: // load the address part of a switch table tuple
					begin
						if (!bus_enable) begin
							bus_enable 		  <= 1'b1;
							switch_table_addr <= switch_table_addr + 16'd2;
						end
						if (bus_enable && bus_ready) begin
							switch_addr <= bus_data_out;
							bus_enable  <= 1'b0;
							bus_address <= {1'b0, switch_table_addr};
							fsm_state   <= FSM_SWITCH_LOAD_VALUE;
						end
					end
				FSM_SWITCH_LOAD_VALUE: // load the value part of a switch table tuple, then compare
					begin
						if (!bus_enable) begin
							bus_enable 		  <= 1'b1;
							switch_table_addr <= switch_table_addr + 16'd2;
						end
						if (bus_enable && bus_ready) begin
							bus_enable <= 1'b0;
							if (switch_addr == 0) begin				// are we at the default?
								reg_PC    <= bus_data_out;
								fsm_state <= FSM_FETCH_OPCODE;
							end else if (bus_data_out == reg_ACC) begin					// compare against value
								reg_PC    <= switch_addr;
								fsm_state <= FSM_FETCH_OPCODE;
							end else begin										// fetch the next tuple
								bus_address <= {1'b0, switch_table_addr};
								fsm_state   <= FSM_SWITCH_LOAD_ADDR;
							end
						end
					end					
				default:
					fsm_state <= FSM_FETCH_OPCODE;
			endcase
		end
	end
endmodule
