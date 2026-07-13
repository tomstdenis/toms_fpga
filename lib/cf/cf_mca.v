/* C-FLEA CPU Design (MCA Edition)

This is a port of cf.v from a monolith FSM to a series of independent FSMs that chain together to form the
same CPU.

The philosophy is there's a bus controller that muxes the various blocks bus outbound signals to the bus.
It selects using a 1-hot "busy" flag system where each of the FSM blocks holds their busy high while they
can access the bus.  The default would be to send to the fetch state.

Each block that can access the bus must lower it's write enable/io flag when not needed so it  doesn't spuriously
raise when they become "busy"

The ISA state (ACC/PC/SP/etc) originates in the fetch block and is passed forwards to the blocks as opcodes are processed
eventually they all meet in a retire state that muxes them back into a coherent ISA state that feeds wrapped around
back into the fetch state to start the process over again.

Each block has three main signals: in_valid, out_valid, and busy.  The in_valid is an input sent by the previous state via its
out_valid signal, this signal is high for 1 cycle only.  The target block then should come out of idle, raise their busy flag if they
use the bus, and do work, once they're done they should clear their busy flag as they raise out_valid.

For sake of convention most nets will start with the name of the block that drives them.

FSM Blocks:

- fetch:
	- ISA: All
	- Input: retire
	- Output: alu, store, flags, branch, stack, misc
	
- alu:
	- ISA: PC, SP, ACC, ALT, INDEX, FLAGS, R0, R1
	- Input: fetch
	- Output: retire
	
- store:
	- ISA: PC, SP, INDEX, 
	- Input: fetch
	- Output: retire
	
- flags:
	- ISA: ACC, (FLAGS)
	- Input: fetch
	- Output: retire
	
- branch:
	- ISA: PC, SP
	- Input: fetch
	- Output: retire
	
- stack:
	- ISA: PC, SP, ACC
	- Input: fetch
	- Output: retire

- misc:
	- ISA: ACC, INDEX, R0, R1
	- Input: fetch
	- Output: retire

- retire:
	- ISA: PC, SP, ACC, ALT, INDEX, FLAGS, R0, R1
	- Input: alu, store, flags, branch, stack, misc
	- Output: fetch

Since retire accepts from multiple states it'll have to comb mux those in defaulting to 
fetch ISA data and then based on which out_valid is high select for different subsets of ISA registers
commit them to their registers and immediately raise out_valid.

The "alu" state may be broken up in the future we'll see.

*/

// version, read by using opcode 0xED which puts this in ACC
`define cf_core_version 8'h10

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

	localparam
		FLAG_SLT = 0,
		FLAG_SGT = 1,
		FLAG_ULT = 2,
		FLAG_UGT = 3,
		FLAG_EQ  = 4;
	
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

	// bus driver
		always @(*) begin
			// default
			bus_address = fetch_bus_address;
			bus_wr_en   = fetch_bus_wr_en;
			bus_data_in = fetch_bus_data_in;
			bus_enable  = fetch_bus_enable;
			bus_io_flag = fetch_bus_io_flag;
			bus_burst   = fetch_bus_burst;
			if (alu_busy) begin
				bus_address = alu_bus_address;
				bus_wr_en   = alu_bus_wr_en;
				bus_data_in = alu_bus_data_in;
				bus_enable  = alu_bus_enable;
				bus_io_flag = alu_bus_io_flag;
				bus_burst   = alu_bus_burst;
			end else if (store_busy) begin
				bus_address = store_bus_address;
				bus_wr_en   = store_bus_wr_en;
				bus_data_in = store_bus_data_in;
				bus_enable  = store_bus_enable;
				bus_io_flag = store_bus_io_flag;
				bus_burst   = store_bus_burst;
			end else if (branch_busy) begin
				bus_address = branch_bus_address;
				bus_wr_en   = branch_bus_wr_en;
				bus_data_in = branch_bus_data_in;
				bus_enable  = branch_bus_enable;
				bus_io_flag = branch_bus_io_flag;
				bus_burst   = branch_bus_burst;
			end else if (stack_busy) begin
				bus_address = stack_bus_address;
				bus_wr_en   = stack_bus_wr_en;
				bus_data_in = stack_bus_data_in;
				bus_enable  = stack_bus_enable;
				bus_io_flag = stack_bus_io_flag;
				bus_burst   = stack_bus_burst;
			end
		end

	// *** Fetch ***
		// state
		reg        fetch_busy;
		
		// ISA 
		reg [15:0] fetch_ACC;
		reg [15:0] fetch_INDEX;
		reg [15:0] fetch_R[0:1];
		reg [15:0] fetch_SP;
		reg [15:0] fetch_PC;
		reg [7:0]  fetch_flags;  			// signed{LT, GT}, unsigned{LT, GT}, EQ
		reg [15:0] fetch_alt;
		reg [7:0]  fetch_cur_opcode;		// opcode byte
		reg [7:0]  fetch_cur_opcode2;
		reg 	   fetch_operand_16;		// is it a 16-bit operand?
		reg [15:0] cycle_count;             // cycle count can be read+reset with opcode 0xEE
	
		// BUS
		reg [16:0] fetch_bus_address;
		reg [15:0] fetch_bus_data_in;
		reg        fetch_bus_wr_en;
		reg        fetch_bus_enable;
		reg		   fetch_bus_io_flag;
		reg		   fetch_bus_burst;
		
		// since fetch reachs out to multiple states it drives their in signals directly
		reg        alu_in_valid;
		reg        store_in_valid;
		reg        flags_in_valid;
		reg        branch_in_valid;
		reg        stack_in_valid;
		reg        misc_in_valid;

		// fetch: Read the next opcode then jump to the next state
		always @(posedge clk) begin
			// these always reset
			alu_in_valid      <= 0;
			store_in_valid    <= 0;
			flags_in_valid    <= 0;
			branch_in_valid   <= 0;
			stack_in_valid    <= 0;
			misc_in_valid     <= 0;

			if (!rst_n) begin
				fetch_PC          <= BOOT_VECTOR;
				cycle_count       <= 0;
				fetch_busy        <= 0;
				fetch_bus_wr_en   <= 0;
				fetch_bus_enable  <= 0;
				fetch_bus_io_flag <= 0;
			end else begin
				cycle_count <= cycle_count + 1'b1;
				if (fetch_in_valid) begin
					// register state and start bus transaction
					fetch_busy  <= 1;
					fetch_ACC   <= retire_ACC;
					fetch_INDEX <= retire_INDEX;
					fetch_R[0]  <= retire_R[0];
					fetch_R[1]  <= retire_R[1]
					fetch_SP    <= retire_SP;
					fetch_PC    <= retire_PC;
					fetch_flags <= retire_flags;
					fetch_alt   <= retire_alt;
					
					// bus
					fetch_bus_enable  <= 1;
					fetch_bus_address <= {1'b0, retire_PC};
					fetch_bus_burst   <= 1;
				end

				// wait for bus_ready
				if (fetch_busy && bus_ready) begin
					// handle bus
					fetch_busy 		  <= 0;
					fetch_bus_enable  <= 0;
					fetch_cur_opcode  <= bus_data_out[7:0];
					fetch_cur_opcode2 <= bus_data_out[15:8];
					
					// dispatch
					if (bus_data_out[7:0] <= 8'h97) begin
						// generic ALU ops that use one of the 8 operand formats
						// so the goal here is to first load an "operand" to pair with
						// an ALU op like ADD, SUB, etc...
						alu_in_valid   <= 1;
						fetch_operand_16 <= ~bus_data_out[3];
					end else if (bus_data_out[7:0] >= 8'h98 && bus_data_out[7:0] <= 8'hB7) begin
						// ST (store) ops (LEAI, ST, STB, STI)
						// the goal here is to load an operand which says where to store ACC or INC
						store_in_valid   <= 1;
						fetch_operand_16 <= (bus_data_out[7:4] == 4'hB) ? 1'b1 : ~bus_data_out[3]; // 16-bit if STI or ST, 8-bit for STB
					end else if (bus_data_out[7:0] >= 8'hB8 && bus_data_out[7:0] <= 8'hC7) begin
						// SHR and SHL: fall back to generic ops but force operand to 8 bit
						alu_in_valid     <= 1;
						fetch_operand_16 <= 0;
					end else if (bus_data_out[7:0] >= 8'hC8 && bus_data_out[7:0] <= 8'hCF) begin
						// LT/LE...UGT/UGE
						flags_in_valid   <= 1;
					end else if (bus_data_out[7:0] >= 8'hD0 && bus_data_out[7:0] <= 8'hD9) begin
						branch_in_valid  <= 1;
					end else if (bus_data_out[7:0] >= 8'hDA && bus_data_out[7:0] <= 8'hDF) begin
						stack_in_valid   <= 1;
					end else if (bus_data_out[7:0] >= 8'hE0) begin 
						misc_in_valid    <= 1;
					end
				end
			end
		end // end of fetch ff block


	// *** alu ***
		// state
		localparam
			alu_fsm_decode  = 3'b001,
			alu_fsm_fetch   = 3'b010,
			alu_fsm_execute = 3'b100;
			
		reg        alu_busy;
		reg [2:0]  alu_fsm;
		reg        alu_out_valid;
		
		// ISA 
		reg [15:0] alu_ACC;
		reg [15:0] alu_INDEX;
		reg [15:0] alu_SP;
		reg [15:0] alu_PC;
		reg [15:0] alu_alt;
		reg [7:0]  alu_flags;
		reg [15:0] alu_operand;
	
		// BUS
		reg [16:0] alu_bus_address;
		reg [15:0] alu_bus_data_in;
		reg        alu_bus_wr_en;
		reg        alu_bus_enable;
		reg		   alu_bus_io_flag;
		reg		   alu_bus_burst;
		
		always @(posedge clk) begin
			alu_out_valid <= 0;
			if (!rst_n) begin
				alu_bus_wr_en   <= 0;
				alu_bus_enable  <= 0;
				alu_bus_io_flag <= 0;
				alu_bus_burst   <= 0;
				alu_fsm         <= alu_fsm_decode;
				alu_busy        <= 0;
				sd_valid        <= 0;
			end else begin
				if (alu_in_valid && alu_fsm[0]) begin
					// busy
					alu_busy  <= 1;

					// fetch operand as needed
					if (~alu_bus_enable) begin
						// forward ISA registers
						alu_ACC   <= fetch_ACC;
						alu_INDEX <= fetch_INDEX;
						alu_SP    <= fetch_SP;
						alu_PC    <= fetch_PC;
						alu_alt   <= fetch_alt;
						alu_flags <= fetch_flags;
						
						// decode opcode 
						alu_bus_enable  <= 1'b1;
						alu_bus_burst   <= 1'b1;
						case(cur_opcode[2:0])
							0: // #n x0 ii(ii)							// immediate 8/16 bit
								begin
									if (fetch_operand_16) begin
										alu_bus_address <= {1'b0, fetch_PC};
										alu_PC 		    <= fetch_PC + 1'b1 + fetch_operand_16;
										alu_bus_burst   <= fetch_operand_16;		// 8 or 16 bit immediate
									end else begin
										alu_bus_enable  <= 1'b0;
										alu_operand     <= {8'b0, fetch_cur_opcode2};
										alu_PC          <= fetch_PC + 1'b1;
										alu_fsm         <= alu_fsm_execute;
									end
								end
							1: // aaaa x1 dd dd							// load from data memory		
								begin
									alu_bus_address <= {1'b0, fetch_PC};		// load address from code memory first
									alu_PC 		    <= fetch_PC + 16'd2;
								end
							2: // I x2 I								// load directly from I
								begin
									alu_bus_address <= {1'b1, fetch_INDEX};	// load from data memory
									alu_bus_burst   <= fetch_operand_16;	// load 8 or 16 bit from [I]
								end
							3: // n,I x3 oo								// load from INDEX+nn
								begin
									alu_bus_address <= {1'b1, fetch_INDEX + {8'b0, fetch_cur_opcode2}};
									alu_bus_burst   <= fetch_operand_16;
									alu_fsm         <= alu_fsm_fetch;
									alu_PC          <= fetch_PC + 1'b1;
								end
							4: // n,S x4 oo								// load from SP+nn
								begin
									alu_bus_address <= {1'b1, fetch_SP + {8'b0, fetch_cur_opcode2}};
									alu_bus_burst   <= reg_operand_16;
									alu_fsm			<= alu_fsm_fetch;
									alu_PC          <= fetch_PC + 1'b1;
								end
							5, 6: // S+ x5 / [S+] x6					// load from S then increment S
								begin
									alu_bus_address <= {1'b1, fetch_SP};		// load from data memory
									alu_SP          <= fetch_SP + 16'd2;		// increment after
								end
							7: // [S] x7								// load from [S]
								begin
									alu_bus_address <= {1'b1, fetch_SP};		// load from data memory
								end
						endcase
					end
					if (alu_bus_enable && bus_ready) begin
						// respond to bus response
						alu_bus_enable <= 0;
						case(fetch_cur_opcode[2:0])
							0: // #n x0 ii(ii)
								begin
									// immediate we have the operand
									alu_operand <= bus_data_out;
									alu_fsm     <= alu_fsm_execute;
								end
							1: // aaaa x1 dd dd
								begin
									// we read the address to read from now we have to actually read it 
									alu_bus_address <= {1'b1, bus_data_out};
									alu_bus_burst   <= fetch_operand_16;
									alu_fsm         <= alu_fsm_fetch;
								end
							2: // I x2 I
								begin
									// we've read [INDEX]
									alu_operand <= bus_data_out;
									alu_fsm     <= alu_fsm_execute;
								end
							5: // S+ x5
								begin
									// popped the operand off the stack
									alu_operand <= bus_data_out;
									alu_fsm     <= alu_fsm_execute;
								end
							6, 7: // [S+] x6, [S] x7
								begin
									alu_bus_address <= {1'b1, bus_data_out};
									alu_bus_burst   <= fetch_operand_16;
									alu_fsm         <= alu_fsm_fetch;
								end
						endcase
					end
				end
				// indirect operand fetching
				if (alu_fsm[1]) begin
					// fetch operand as needed indirectly
					if (~alu_bus_enable) begin
						// start bus
						alu_bus_enable <= 1;
					end
					if (alu_bus_enable && bus_ready) begin
						// respond to bus response
						alu_bus_enable <= 0;
						alu_operand    <= bus_data_out;					// finally have the operand 
						alu_fsm        <= alu_fsm_execute;
					end
				end
				// execute the opcode finally
				if (alu_fsm[2]) begin
					alu_out_valid <= 1;
					alu_busy      <= 0;
					alu_fsm       <= alu_fsm_decode;
					case(fetch_cur_opcode[7:4])
						4'h0: // LD/LDB
							begin
								alu_ACC <= alu_operand;
							end
						4'h1: // ADD/ADDB
							begin
								alu_ACC <= alu_ACC + alu_operand;
							end
						4'h2: // SUB/SUBB
							begin
								alu_ACC <= alu_ACC - alu_operand;
							end
						4'h3: // MUL/MULB
							begin
								{alu_alt,alu_ACC} <= alu_ACC * alu_operand;
							end
						4'h4: // DIV/DIVB
							begin
								if (!sd_ready) begin
									// stay put
									alu_out_valid <= 0;
									alu_busy      <= 1;
									alu_fsm       <= alu_fsm_execute;
								end
								
								if (!sd_valid && !sd_ready) begin
									sd_num   <= alu_ACC;
									sd_denom <= alu_operand;
									sd_valid <= 1'b1;
								end
								if (sd_valid && sd_ready) begin
									fsm_state <= FSM_FETCH_OPCODE;
									alu_ACC   <= sd_quotient;						// ACC gets quotient and we put remainder in ALT location
									alu_alt   <= sd_remainder;
									sd_valid  <= 1'b0;
								end
							end
						4'h5: // AND/ANDB
							begin
								alu_ACC <= alu_ACC & alu_operand;
							end
						4'h6: // OR/ORB
							begin
								alu_ACC <= alu_ACC | alu_operand;
							end
						4'h7: // XOR/XORB
							begin
								alu_ACC <= alu_ACC ^ alu_operand;
							end
						4'h8: // CMP/CMPB
							begin
								alu_flags[FLAG_EQ]  <= (alu_ACC == alu_operand) ? 1'b1 : 1'b0;
								alu_ACC             <= (alu_ACC == alu_operand) ? 16'd1 : 16'd0;
								if (alu_operand_16) begin
									// compare full 16 bits
									alu_flags[FLAG_SLT] <= ($signed(alu_ACC) < $signed(alu_operand)) ? 1'b1 : 1'b0;
									alu_flags[FLAG_SGT] <= ($signed(alu_ACC) > $signed(alu_operand)) ? 1'b1 : 1'b0;
								end else begin
									// compare only bottom 8 bits for CMPB
									alu_flags[FLAG_SLT] <= ($signed(alu_ACC[7:0]) < $signed(alu_operand[7:0])) ? 1'b1 : 1'b0;
									alu_flags[FLAG_SGT] <= ($signed(alu_ACC[7:0]) > $signed(alu_operand[7:0])) ? 1'b1 : 1'b0;
								end
								alu_flags[FLAG_ULT] <= (alu_ACC < alu_operand) ? 1'b1 : 1'b0;
								alu_flags[FLAG_UGT] <= (alu_ACC > alu_operand) ? 1'b1 : 1'b0;
							end
						4'h9: // LDI
							begin
								alu_INDEX <= alu_operand;
							end
						default:
							begin
								// SHR/SHL opcodes
								case(cur_opcode[7:3])
									5'h17: // SHR
										begin
											alu_ACC <= alu_ACC >> alu_operand[3:0];
										end
									5'h18: // SHL
										begin
											alu_ACC <= alu_ACC << alu_operand[3:0];
										end
									default: begin end
								endcase
							end
					endcase
				end
			end
		end // end of alu ff block
		


endmodule
