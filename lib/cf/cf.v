/* C-FLEA CPU Design */
`default_nettype none
``timescale 1ns/1ps

module cf_cpu(
	input wire clk,
	input wire rst_n,
	
	// bus
	output reg [16:0] bus_address,		// 0..FFFF CODE, 10000..1FFFF DATA (can be merged to form a 64K space)
	output reg bus_wr_en,				// write enable
	output reg bus_io_flag,				// I/O bus activity (e.g. inp/outp)
	output reg bus_burst,				// high == 16 bit transfer
	output reg [15:0] bus_data_out,		// output
	output reg bus_enable,				// tell the bus we're good to go
	
	input wire bus_ready,				// bus tells us it's ready
	input wire [15:0] bus_data_in		// input
);

	// ISA state
	reg [15:0] reg_ACC;
	reg [15:0] reg_INDEX;
	reg [15:0] reg_SP;
	reg [15:0] reg_PC;
	reg [7:0]  reg_flags;  				// signed{LT, GT}, unsigned{LT, GT}, EQ
	reg [15:0] reg_alt;
	reg [7:0]  cur_opcode;				// opcode byte
	reg [15:0] cur_operand;				// the operand
	
	localparam
		FLAG_SLT = 0,
		FLAG_SGT = 1,
		FLAG_ULT = 2,
		FLAG_UGT = 3,
		FLAG_EQ  = 4;
	
	// FSM state
	reg [5:0]  fsm_state;
	reg [5:0]  fsm_tag;

	localparam
		FSM_FETCH_OPCODE             = 0,
		FSM_FETCH_ALU_OPERAND_00_97  = 1,
		FSM_FETCH_ALU_OPERAND2_00_97 = 2,
		FSM_EXECUTE_ALU_OPCODE_00_97 = 3,
		FSM_FETCH_ALU_OPERAND_98_B7  = 4;
		
		
	always @(posedge clk) begin
		if (!rst_n) begin
			bus_address  <= 0;
			bus_wr_en    <= 0;
			bus_io_flag  <= 0;
			bus_burst    <= 0;
			bus_data_out <= 0;
			bus_enable   <= 0;
			reg_ACC		 <= 0;
			reg_INDEX    <= 0;
			reg_SP       <= 0;
			reg_PC       <= 0;
			reg_flags    <= 0;
			cur_opcode   <= 0;
			cur_operand  <= 0;
			fsm_state    <= FSM_FETCH_OPCODE;
			fsm_tag      <= 0;
		end else begin
			case(fsm_state)
				FSM_FETCH_OPCODE:
					begin
						// fetch next opcode byte
						if (!bus_enable) begin
							bus_enable  <= 1'b1;
							bus_wr_en   <= 1'b0;
							bus_io_flag <= 1'b0;
							bus_burst   <= 1'b0;
							bus_address <= {1'b0, reg_PC};
							reg_PC      <= reg_PC + 1'b1;
						end
						if (bus_enable && bus_ready) begin
							cur_operand <= bus_data_out[7:0];
							bus_enable  <= 0;
							if (bus_data_out[7:0] < 8'h98) begin
								// generic ALU ops that use one of the 8 operand formats
								// so the goal here is to first load an "operand" to pair with
								// an ALU op like ADD, SUB, etc...
								fsm_state <= FSM_FETCH_ALU_OPERAND_00_97;
							end else if (bus_data_out[7:0] > 8'h97 && bus_data_out[7:0] < 8'hB8) begin
								// ST (store) ops
								// the goal here is to load an operand which says where to store ACC or INC
								fsm_state <= FSM_FETCH_ALU_OPERAND_98_B7;
							end
						end
					end
				FSM_FETCH_ALU_OPERAND_00_97:
					// start of decoding one of the 8 operand modes
					begin
						if (!bus_enable) begin
							case(cur_operand[2:0])
								0: // #n x0 ii(ii)							// immediate 8/16 bit
									begin
										bus_enable  <= 1'b1;
										bus_address <= {1'b0, reg_PC};
										reg_PC 		<= reg_PC + 1'b1 + cur_opcode[3];
										bus_burst   <= cur_opcode[3];		// bit 3 determines if the operand is 16 bits
										bus_wr_en   <= 1'b0;
									end
								1: // aaaa x1 dd dd							// load from data memory		
									begin
										bus_enable  <= 1'b1;
										bus_address <= {1'b0, reg_PC};		// load address from code memory first
										reg_PC 		<= reg_PC + 16'd2;
										bus_burst   <= 1'b1;
										bus_wr_en   <= 1'b0;
									end
								2: // I x2 I								// load directly from I
									begin
										bus_enable  <= 1'b1;
										bus_address <= {1'b1, reg_INDEX};	// load from data memory
										bus_burst   <= cur_opcode[3];		// bit 3 determines if the operand is 16 bits
										bus_wr_en   <= 1'b0;										
									end
								3: // n,I x3 oo								// load from INDEX+nn
									begin
										bus_enable  <= 1'b1;
										bus_address <= {1'b0, reg_PC};
										reg_PC 		<= reg_PC + 1'b1;
										bus_burst   <= 0;					// offset is only 8 bits 
										bus_wr_en   <= 1'b0;
									end
								4: // n,S x4 oo								// load from SP+nn
									begin
										bus_enable  <= 1'b1;
										bus_address <= {1'b0, reg_PC};
										reg_PC 		<= reg_PC + 1'b1;
										bus_burst   <= 0;					// offset is only 8 bits 
										bus_wr_en   <= 1'b0;
									end
								5: // S+ x5									// load from S then increment S
									begin
										bus_enable  <= 1'b1;
										bus_address <= {1'b1, reg_SP};		// load from data memory
										bus_burst   <= cur_opcode[3];		// bit 3 determines if the operand is 16 bits
										bus_wr_en   <= 1'b0;										
										reg_SP      <= reg_SP + 16'd2;		// increment after
									end
								6: // [S+] x6								// load from [S] then increment S
									begin
										bus_enable  <= 1'b1;
										bus_address <= {1'b1, reg_SP};		// load from data memory
										bus_burst   <= cur_opcode[3];		// bit 3 determines if the operand is 16 bits
										bus_wr_en   <= 1'b0;										
										reg_SP      <= reg_SP + 16'd2;		// increment after
									end
								7: // [S] x7								// load from [S]
									begin
										bus_enable  <= 1'b1;
										bus_address <= {1'b1, reg_SP};		// load from data memory
										bus_burst   <= cur_opcode[3];		// bit 3 determines if the operand is 16 bits
										bus_wr_en   <= 1'b0;										
									end
							endcase
						end
						if (bus_enable && bus_ready) begin
							// second half of initial operand fetch.  In some cases we're done
							// in other cases what we've loaded so far is the address we need
							// to actually fetch the operand.
							bus_enable <= 1'b0;
							case(cur_operand[2:0])
								0: // #n x0 ii(ii)
									begin
										reg_operand <= bus_data_out;
										fsm_state   <= FSM_EXECUTE_ALU_OPCODE_00_97;
									end
								1: // aaaa x1 dd dd
									begin
										// we read the address to read from now we have to actually read it 
										bus_address <= bus_data_out;
										bus_burst   <= cur_opcode[3];
										fsm_state   <= FSM_FETCH_ALU_OPERAND2_00_97;
									end
								2: // I x2 I
									begin
										reg_operand <= bus_data_out;
										fsm_state   <= FSM_EXECUTE_ALU_OPCODE_00_97;
									end
								3: // n,I x3 oo
									begin
										bus_address <= reg_INDEX + bus_data_out;
										bus_burst   <= cur_opcode[3];
										fsm_state   <= FSM_FETCH_ALU_OPERAND2_00_97;
									end
								4: // n,S x4 oo
									begin
										bus_address <= reg_SP + bus_data_out;
										bus_burst   <= cur_opcode[3];
										fsm_state   <= FSM_FETCH_ALU_OPERAND2_00_97;
									end
								5: // S+ x5
									begin
										reg_operand <= bus_data_out;
										fsm_state   <= FSM_EXECUTE_ALU_OPCODE_00_97;
									end
								6: // [S+] x6
									begin
										reg_operand <= bus_data_out;
										bus_burst   <= cur_opcode[3];
										fsm_state   <= FSM_FETCH_ALU_OPERAND2_00_97;
									end
								7: // [S] x7
									begin
										reg_operand <= bus_data_out;
										bus_burst   <= cur_opcode[3];
										fsm_state   <= FSM_FETCH_ALU_OPERAND2_00_97;
									end
							endcase
						end
					end
				FSM_FETCH_ALU_OPERAND2_00_97:								// 2nd FSM state for fetching operands for ALU ops upto 0x97
					begin
						if (!bus_enable) begin
							// bus was otherwise programmed already we just need to enable it
							bus_enable  <= 1'b1
						end
						if (bus_enable && bus_ready) begin
							bus_enable  <= 1'b0;
							reg_operand <= bus_data_out;					// finally have the operand 
							fsm_state   <= FSM_EXECUTE_ALU_OPCODE_00_97;
						end
					end
				FSM_EXECUTE_ALU_OPCODE_00_97:					// execute opcodes upto byte 0x97
					begin
						// we're done after this so we fetch
						fsm_state <= FSM_FETCH_OPCODE;
						case(cur_opcode[7:4]) begin
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
							4'h4: // DIV/DIB
								begin
									// TODO: program division block and transition to wait for div
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
									reg_flags[FLAG_SLT] <= ($signed(reg_ACC) < $signed(reg_operand)) ? 1'b1 : 1'b0;
									reg_flags[FLAG_SGT] <= ($signed(reg_ACC) > $signed(reg_operand)) ? 1'b1 : 1'b0;
									reg_flags[FLAG_ULT] <= (reg_ACC < reg_operand) ? 1'b1 : 1'b0;
									reg_flags[FLAG_UGT] <= (reg_ACC > reg_operand) ? 1'b1 : 1'b0;									
								end
							4'h9: // LDI
								begin
									reg_INDEX <= reg_operand;
								end
						endcase
					end
				FSM_FETCH_ALU_OPERAND_98_B7:								// handle ST (store) operand fetching
					begin
						if (!bus_enable) begin
							case(cur_operand[2:0])
								1: // aaaa x1 dd dd
									begin
									end
								2: // I x2 I
									begin
									end
								3: // n,I x3 oo
									begin
									end
								4: // n,S x4 oo
									begin
									end
								6: // [S+] x6
									begin
									end
								7: // [S] x7
									begin
									end
							endcase
						end
						if (bus_enable && bus_ready) begin
							case(cur_operand[2:0])
								1: // aaaa x1 dd dd
									begin
									end
								2: // I x2 I
									begin
									end
								3: // n,I x3 oo
									begin
									end
								4: // n,S x4 oo
									begin
									end
								6: // [S+] x6
									begin
									end
								7: // [S] x7
									begin
									end
							endcase
						end
					end
				default:
					fsm_state <= FSM_FETCH_OPCODE;
			endcase
		end
	end
endmodule
