module ib16 (
	input clk,
	input rst_n,
	
	// bus signals
	output reg bus_enable,
	output reg bus_wr_en,
	output reg [15:0] bus_address,
	output reg [7:0] bus_data_in,
	input bus_ready,
	input [7:0] bus_data_out,
	input bus_irq
);
	// memory map
	localparam
		STACK_ADDRESS   = 16'h2100;

	// ISA registers
	localparam
		CARRY_FLAG = 7,
		ZERO_FLAG  = 6,
		WRITE_INCR = 1,
		READ_INCR  = 0;

	reg [15:0]	reg_pc;								// PC register
	reg [7:0]	reg_sp;								// SP (stack) register
	reg [7:0]	reg_sreg;							// SREG (status register)
	reg [7:0]	reg_wi;								// WI (write index)
	reg [7:0]	reg_ri;								// RI (read index)
	reg [7:0]	reg_rr [0:15];
	reg [7:0]	reg_ra;
	reg [7:0]	reg_rb;
	
	wire carry_flag = reg_sreg[CARRY_FLAG];
	wire zero_flag  = reg_sreg[ZERO_FLAG];
	wire write_incr_flag = reg_sreg[WRITE_INCR];
	wire read_incr_flag = reg_sreg[READ_INCR];
	
	// CPU state		
	reg [4:0]	fsm_state;
	reg [4:0]	fsm_tag;
	reg [4:0]	fsm_cycle;
	reg 		mask_irq;
	reg [15:0]	cur_opcode;
	reg			update_flags;						// 1 means RETIRE should update the flags
	reg [8:0]	result_dff;							// the value to be retired
	
	// various wires to look at the opcode
	wire opcode_isn[3:0]  = cur_opcode[15:12];		// instruction
	wire opcode_opd[3:0]  = cur_opcode[11:8];		// destination
	wire opcode_opa[3:0]  = cur_opcode[7:4];		// operand a
	wire opcode_opb[3:0]  = cur_opcode[3:0];		// operand b
	wire opcode_8imm[7:0] = cur_opcode[7:0];		// 8IMM
	wire opcode_12imm[11:0] = cur_opcode[11:0];		// 12IMM
	wire opcode_9simm[15:0]	= {{6}{cur_opcode[8]}, cur_opcode[8:0];		// 9SIMM

	localparam
		OPCODE_MOV = 0,
		OPCODE_LDI = 1,
		OPCODE_ADD = 2,
		OPCODE_ADC = 3,
		OPCODE_SUB = 4,
		OPCODE_XOR = 5,
		OPCODE_AND = 6,
		OPCODE_OR  = 7,
		OPCODE_SHF = 8,
		OPCODE_LDM = 9,
		OPCODE STM = 10,
		OPCODE_CAL = 11,
		OPCODE_RET = 12,
		OPCODE_JMP = 13,
		OPCODE_SRS = 14,
		OPCODE_RTI = 15;
	
	localparam
		FSM_RAM			= 0,
		FSM_FETCH		= 1,
		FSM_DECODE		= 2,
		FSM_RETIRE		= 3;

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			reg_pc			<= 0;
			reg_sp			<= 0;
			reg_sreg		<= 0;
			reg_wi			<= 0;
			reg_ri			<= 0;
			fsm_state		<= FSM_FETCH;
			fsm_tag			<= 0;
			fsm_cycle		<= 0;
			mask_irq		<= 0;
			update_flags	<= 0;
			result_dff		<= 0;
		end else begin
			case(state)
				FSM_RAM: // issue bus transaction
					begin
						// previous cycle drove the bus_* nets, at this point we're just waiting
						if (bus_ready) begin
							bus_wr_en	<= 1'b0;
							bus_enable	<= 1'b0;
							state 		<= tag;
						end
					end
				FSM_FETCH: // fetch opcode
					begin
						case(fsm_cycle)
							0:
								begin
									bus_enable 	<= 1'b1;				// enable bus
									bus_address <= PC;					// read from PC
									tag			<= FSM_FETCH;			// jump back here when done
									state		<= FSM_RAM;
									fsm_cycle	<= fsm_cycle + 1'b1;	// increment FSM cycle counter
								end
							1:
								begin
									cur_opcode[7:0] <= bus_data_out;	// store byte
									bus_enable		<= 1'b1;
									bus_address 	<= PC + 1'b1;		// read from PC+1
									PC				<= PC + 16'd2;		// increment PC by 2
									tag				<= FSM_PREDECODE;	// jump to decode when done
									state			<= FSM_RAM;
									fsm_cycle 		<= 0;
								end
							default: begin end
						endcase
					end
				FSM_PREDECODE: // read registers
					begin
						case(fsm_cycle)
							0:
								begin
									reg_ra		<= reg_rr[opcode_opa];
									fsm_cycle	<= 1;
								end
							1:
								begin
									reg_rb		<= reg_rr[opcode_opb];
									fsm_cycle	<= 0;
									state		<= FSM_DECODE;
								end
						endcase
					end
				FSM_DECODE:	// decode upcode
					begin
						cur_opcode[15:8] 	<= bus_data_out;		// store 2nd opcode byte
						case(bus_data_out[7:4])						// switch on the insn which is cur_opcode[15:12] or bus_data_out[7:4]
							OPCODE_MOV:
								begin
								end
							OPCODE_LDI:
								begin
									result_dff	<= {1'b0, opcode_8imm};
									state		<= FSM_RETIRE;
								end
							OPCODE_ADD:
								begin
									result_dff	<= {1'b0, reg_ra} + {1'b0, reg_rb};
									state		<= FSM_RETIRE;
								end
							OPCODE_ADC:
								begin
									result_dff	<= {1'b0, reg_ra} + {1'b0, reg_rb} + reg_sreg[CARRY_FLAG];
									state		<= FSM_RETIRE;
								end
							OPCODE_SUB:
								begin
									result_dff	<= {1'b0, reg_ra} - {1'b0, reg_rb};
									state		<= FSM_RETIRE;
								end
							OPCODE_XOR:
								begin
									result_dff	<= {1'b0, reg_ra} ^ {1'b0, reg_rb};
									state		<= FSM_RETIRE;
								end
							OPCODE_AND:
								begin
									result_dff	<= {1'b0, reg_ra} & {1'b0, reg_rb};
									state		<= FSM_RETIRE;
								end
							OPCODE_OR:
								begin
									result_dff	<= {1'b0, reg_ra} | {1'b0, reg_rb};
									state		<= FSM_RETIRE;
								end
							OPCODE_SHF: // shifts (modifier == opcode_opa, register is reg_rb)
								begin
									state		<= FSM_RETIRE;
									case(opcode_opa)
										0: // SHR
											result_dff <= reg_rb >> 1;
										1: // ROR
											result_dff <= {reg_rb[0], reg_rb[0], reg_rb[7:1]};
										2: // ROL
											result_dff <= {reg_rb[7], reg_rb[6:0], reb_rb[7]};
										3: // SWAP
											result_dff <= {1'b0, reg_rb[3:0], reg_rb[7:4]};
										default: begin end;
									endcase
								end
							OPCODE_LDM: // load
								begin
									bus_enable			<= 1
									tag 				<= FSM_LDM_PART2;
									state				<= FSM_RAM;
									if (opcode_opa == opcode_opb && opcode_opa == 15) begin
										// pop
										bus_address		<= STACK_ADDRESS + reg_sp - 1;
										reg_sp			<= reg_sp - 1;
									end else begin
										// load from memory
										bus_address		<= {reg_ra, reg_rb} + (reg_sreg[READ_INCR] ? reg_ri : 0);
										reg_ri			<= reg_ri + 1;
									end
								end	
							OPCODE_STM:	// store
								begin
									bus_enable			<= 1;
									bus_wr_en			<= 1;
									tag					<= FSM_FETCH;
									state				<= FSM_RAM;
									bus_data_in			<= reg_rr[opcode_opd];
									if (opcode_opa == opcode_opb && opcode_opa == 15) begin
										// push
										bus_address		<= STACK_ADDRESS + reg_sp;
										reg_sp			<= reg_sp + 1;
									end else begin
										// store to memory
										bus_address		<= {reg_ra, reg_rb} + (reg_sreg[WRITE_INCR] ? reg_wi : 0);
										reg_wi			<= reg_wi + 1;
									end
								end
							default: begin end
						endcase
					end
				FSM_RETIRE:	// retire isn
					begin
						reg_rr[opcode_opd]		<= result_dff[7:0];
						reg_sreg[ZERO_FLAG]		<= result_dff[7:0] ? 1'b0 : 1'b1;
						reg_sreg[CARRY_FLAG]	<= result_dff[8];
						state					<= FSM_FETCH;
					end
				FSM_LDM_PART2: // handle result from LDM
					begin
						result_dff				<= {1'b0, bus_data_out};
						state					<= FSM_RETIRE;
					end
				default: begin end;	
			endcase
		end
	end

endmodule
