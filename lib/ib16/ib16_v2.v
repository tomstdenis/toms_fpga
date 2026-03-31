`timescale 1ns/1ps

module ib16 #(
    parameter STACK_ADDRESS = 16'h1F00,
    parameter IRQ_VECTOR    = 16'h1E00
) (
	input clk,
	input rst_n,
	
	// bus signals
	output reg bus_enable,
	output reg bus_wr_en,
	output [15:0] bus_address, 
	output reg [7:0] bus_data_in,
	input bus_ready,
	input [7:0] bus_data_out,
	input bus_irq
);
    // BUS
    reg [15:0] bus_address_terma;
    reg [7:0] bus_address_termb;
    assign bus_address = bus_address_terma + {8'b0, bus_address_termb};

	// ISA registers
	localparam
		CARRY_FLAG = 7,
		ZERO_FLAG  = 6,
		WRITE_INCR = 1,
		READ_INCR  = 0;

	reg [15:0]	reg_pc;								// PC register
	reg [15:0]  reg_irq_pc;							// when an IRQ happens save the PC
	reg [7:0]	reg_sp;								// SP (stack) register
	reg [7:0]	reg_sreg;							// SREG (status register)
	reg [7:0]	reg_wi;								// WI (write index)
	reg [7:0]	reg_ri;								// RI (read index)
	reg [7:0]	reg_rr [0:31];						// GPRs (16, + 16 for IRQ)
	reg [7:0]	reg_rr2 [0:31];						// GPRs (16, + 16 for IRQ) (mirror)
	reg [7:0]	reg_ra;
	reg [7:0]	reg_rb;
	
	wire carry_flag = reg_sreg[CARRY_FLAG];
	wire zero_flag  = reg_sreg[ZERO_FLAG];
	wire write_incr_flag = reg_sreg[WRITE_INCR];
	wire read_incr_flag = reg_sreg[READ_INCR];
	
	// CPU state		
	reg [5:0]	state;
	reg [5:0]	tag;
	reg [2:0]	fsm_cycle;
	reg 		mask_irq;
	reg [15:0]	cur_opcode;
	reg [9:0]	result_dff;							// the value to be retired
	
	// various wires to look at the opcode
	wire [3:0] opcode_isn  = cur_opcode[15:12];		// instruction
	wire [3:0] opcode_opd  = cur_opcode[11:8];		// destination
	wire [3:0] opcode_opa  = cur_opcode[7:4];		// operand a
	wire [3:0] opcode_opb  = cur_opcode[3:0];		// operand b
	wire [2:0] opcode_3imm = cur_opcode[11:9];		// 3IMM
	wire [7:0] opcode_8imm = cur_opcode[7:0];		// 8IMM
	wire [11:0] opcode_12imm = cur_opcode[11:0];		// 12IMM
	wire [15:0] opcode_9simm = { {6{cur_opcode[8]}}, cur_opcode[8:0], 1'b0 };

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
		OPCODE_STM = 10,
		OPCODE_CAL = 11,
		OPCODE_RET = 12,
		OPCODE_JMP = 13,
		OPCODE_SRS = 14,
		OPCODE_RTI = 15;
	
	localparam
		FSM_FETCH		= 0,				// FETCH next opcode (this should be 0 so we can use nice resets on the state DFFs)
		FSM_RAM			= 1,
		FSM_PREDECODE	= 2,
		FSM_RETIRE		= 3,
		FSM_LDM_PART2   = 4,
		FSM_DECODE		= 5;

	// ALU
	always @(*) begin
		result_dff = {10'b0}; // default no-op
		
		if (opcode_isn == OPCODE_MOV) begin
			case(opcode_opa[2:0])			// modifier == opa, reg is reg_rb
				0: // MOV
					begin
						result_dff		= {2'b10, reg_rb};
					end
				1: // MOVC
					begin
						if (carry_flag) begin
							result_dff 	= {2'b10, reg_rb};
						end else begin
							result_dff 	= {2'b00, reg_rb}; // no store
						end
					end
				2: // MOVNC
					begin
						if (!carry_flag) begin
							result_dff 	= {2'b10, reg_rb};
						end else begin
							result_dff 	= {2'b00, reg_rb}; // no store
						end
					end
				3: // MOVZ
					begin
						if (zero_flag) begin
							result_dff 	= {2'b10, reg_rb};
						end else begin
							result_dff 	= {2'b00, reg_rb}; // no store
						end
					end
				4: // MOVNZ
					begin
						if (!zero_flag) begin
							result_dff 	= {2'b10, reg_rb};
						end else begin
							result_dff 	= {2'b00, reg_rb}; // no store
						end
					end
				5: // MOVRI
					begin
						result_dff 		= { 2'b10, reg_ri};
					end
				6: // MOVWI
					begin
						result_dff 		= { 2'b10, reg_wi};
					end
				7: // MOVSREG
					begin
						result_dff 		= { 2'b10, reg_sreg};
					end
			endcase
		end
		if (opcode_isn == OPCODE_LDI) begin
			result_dff	= {2'b10, opcode_8imm};
		end
		if (opcode_isn == OPCODE_ADD || opcode_isn == OPCODE_ADC || opcode_isn == OPCODE_SUB) begin
			result_dff	= {1'b1, {1'b0, reg_ra} +
						   (opcode_isn == OPCODE_SUB ? 
								{1'b0, -reg_rb} :
								{1'b0, reg_rb}) +
						   {8'b0, ((opcode_isn == OPCODE_ADC ? 1'b1 : 1'b0) & carry_flag)}};
		end
		if (opcode_isn == OPCODE_XOR) begin
			result_dff	= {2'b10, reg_ra ^ reg_rb};
		end
		if (opcode_isn == OPCODE_AND) begin
			result_dff	= {2'b10, reg_ra & reg_rb};
		end
		if (opcode_isn == OPCODE_OR) begin
			result_dff	= {2'b10, reg_ra | reg_rb};
		end
		if (opcode_isn == OPCODE_SHF) begin
			case(opcode_opa[2:0])
				0: // SHR
					result_dff = {1'b1, 2'b0, reg_rb[7:1]};
				1: // SAR
					result_dff = {1'b1, 1'b0, reg_rb[7], reg_rb[7:1]};
				2: // ROR
					result_dff = {1'b1, reg_rb[0], reg_rb[0], reg_rb[7:1]};
				3: // ROL
					result_dff = {1'b1, reg_rb[7], reg_rb[6:0], reg_rb[7]};
				4: // SWAP
					result_dff = {1'b1, 1'b0, reg_rb[3:0], reg_rb[7:4]};
				5: // INC
					result_dff = {1'b1, 1'b0, reg_rb} + 1'b1;
				6: // DEC
					result_dff = {1'b1, 1'b0, reg_rb} - 1'b1;
				7: // NOT
					result_dff = {1'b1, 1'b0, ~reg_rb};
			endcase
		end
	end
	
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			reg_pc			<= 0;
			reg_irq_pc		<= 0;
			reg_sp			<= 0;
			reg_sreg		<= 0;
			reg_wi			<= 0;
			reg_ri			<= 0;
			state			<= FSM_FETCH;
			tag				<= 0;
			fsm_cycle		<= 0;
			mask_irq		<= 0;
			reg_ra			<= 0;
			bus_enable		<= 0;
			bus_wr_en		<= 0;
			bus_data_in		<= 0;
			cur_opcode		<= 0;
            bus_address_terma <= 0;
            bus_address_termb <= 0;
		end else begin
            if (state == FSM_RAM) begin
                // previous cycle drove the bus_* nets, at this point we're just waiting
                if (bus_ready) begin
                    bus_wr_en	<= 1'b0;
                    bus_enable	<= 1'b0;
                    state 		<= tag;
                end
            end
            if (state == FSM_FETCH) begin
                if (bus_irq && !mask_irq) begin
                    reg_irq_pc	    <= {reg_pc[15:1], 1'b0}; // force LSB to zero in case we IRQ in the middle of a fetch
                    mask_irq 	    <= 1;
                    reg_pc	 	    <= IRQ_VECTOR;
                    fsm_cycle	    <= 0;
                end else begin
                    bus_enable		<= 1'b1;
                    bus_address_terma <= reg_pc;		        // read from PC
                    bus_address_termb <= 0;
                    reg_pc			<= reg_pc + 1'd1;		// increment PC
                    state			<= FSM_RAM;
                    if (fsm_cycle == 0) begin
                        tag				<= FSM_FETCH;			// jump back here when done
                        fsm_cycle		<= 1;	// increment FSM cycle counter
                    end
                    if (fsm_cycle == 1) begin
                        cur_opcode[7:0] <= bus_data_out;		// store byte
                        tag				<= FSM_PREDECODE;		// jump to decode when done
                        fsm_cycle 		<= 0;
                    end
                end
            end
            if (state == FSM_PREDECODE)	begin
                reg_ra				<= reg_rr[opcode_opa + (mask_irq ? 16 : 0)];
                reg_rb				<= reg_rr2[opcode_opb + (mask_irq ? 16 : 0)];
                cur_opcode[15:8]	<= bus_data_out;				// store top 8 bits of opcode
                state				<= (bus_data_out[7:4] <= OPCODE_SHF) ? FSM_RETIRE : FSM_DECODE + {2'b0, bus_data_out[7:4]};
            end
            if (state == FSM_DECODE + OPCODE_LDM) begin
                bus_enable			<= 1;
                tag 				<= FSM_LDM_PART2;
                state				<= FSM_RAM;
                if (opcode_opa == 15 && opcode_opb == 15) begin
                    // pop
                    bus_address_terma <= STACK_ADDRESS;
                    bus_address_termb <= reg_sp - 1'b1;
                    reg_sp			<= reg_sp - 8'b1;
                end else begin
                    // load from memory
                    bus_address_terma <= {reg_ra, reg_rb};
                    bus_address_termb <= (reg_sreg[READ_INCR] ? reg_ri : 8'b0);
                    reg_ri			<= reg_ri + 8'b1;
                end
            end
            if (state == FSM_DECODE + OPCODE_STM) begin
                bus_enable			<= 1;
                bus_wr_en			<= 1;
                tag					<= FSM_FETCH;
                state				<= FSM_RAM;
                bus_data_in			<= reg_rr[(mask_irq ? 16 : 0) + opcode_opd];
                if (opcode_opa == 15 && opcode_opb == 15) begin
                    // push
                    bus_address_terma <= STACK_ADDRESS;
                    bus_address_termb <= reg_sp;
                    reg_sp			<= reg_sp + 8'b1;
                end else begin
                    // store to memory
                    bus_address_terma <= {reg_ra, reg_rb};
                    bus_address_termb <= (reg_sreg[WRITE_INCR] ? reg_wi : 8'b0);
                    reg_wi			<= reg_wi + 8'b1;
                end
            end
            if (state == FSM_DECODE + OPCODE_CAL) begin
                bus_enable		<= 1;
                bus_wr_en		<= 1;
                bus_address_terma <= STACK_ADDRESS;
                bus_address_termb <= reg_sp;
                reg_sp			<= reg_sp + 8'b1;
                state			<= FSM_RAM;
                case(fsm_cycle)
                    0:					// store reg_pc[7:0]
                        begin
                            bus_data_in		<= reg_pc[7:0];
                            tag				<= FSM_DECODE + OPCODE_CAL;
                            fsm_cycle		<= 1;
                        end
                    1:					// store reg_pc[15:8]
                        begin
                            bus_data_in		<= reg_pc[15:8];
                            tag				<= FSM_FETCH;
                            fsm_cycle		<= 0;
                            reg_pc			<= {3'b0, opcode_12imm, 1'b0};
                        end
                endcase
            end
            if (state == FSM_DECODE + OPCODE_RTI) begin
                mask_irq 					<= 0;
                reg_pc	 					<= reg_irq_pc;
                state						<= FSM_FETCH;
            end
            if (state == FSM_DECODE + OPCODE_RET) begin
                if (fsm_cycle != 2) begin
                    bus_enable		<= 1;
                    bus_address_terma <= STACK_ADDRESS;
                    bus_address_termb <= reg_sp - 1'b1;
                    reg_sp			<= reg_sp - 8'b1;
                    tag				<= FSM_DECODE + OPCODE_RET;
                    state			<= FSM_RAM;
                end
                case(fsm_cycle)
                    0:					// load PC[15:8]
                        begin
                            fsm_cycle		<= 1;
                        end
                    1:					// load PC[7:0]
                        begin
                            fsm_cycle		<= 2;
                            reg_pc[15:8]	<= bus_data_out;
                        end
                    2:					// capture value
                        begin
                            reg_pc[7:0]		<= bus_data_out;
                            fsm_cycle		<= 0;
                            state			<= FSM_FETCH;
                        end
                endcase
            end
            if (state == FSM_DECODE + OPCODE_JMP) begin
                if ((opcode_3imm == 0) ||                           // JMP
                    (opcode_3imm == 1 && carry_flag) ||             // JC
                    (opcode_3imm == 2 && ~carry_flag) ||            // JNC
                    (opcode_3imm == 3 && zero_flag) ||              // JZ
                    (opcode_3imm == 4 && ~zero_flag)) begin         // JNZ
                    reg_pc <= reg_pc + opcode_9simm;
                end
                state <= FSM_FETCH;
            end
            if (state == FSM_DECODE + OPCODE_SRS) begin
                // SREG = {SREG[7:6] & ~imm8[7:6], imm8[5:0]} 
                // W1C for carry/zero, store for other bits
                reg_sreg    <= {reg_sreg[7:6] & ~opcode_8imm[7:6], opcode_8imm[5:0]};
                reg_ri      <= 8'h00; // Clear RI
                reg_wi      <= 8'h00; // Clear WI
                mask_irq    <= opcode_8imm[2];
                state       <= FSM_FETCH;
            end
            if (state == FSM_RETIRE) begin
				if (result_dff[9]) begin
					reg_rr[(mask_irq ? 16 : 0) + opcode_opd]	<= result_dff[7:0];
					reg_rr2[(mask_irq ? 16 : 0) + opcode_opd]	<= result_dff[7:0]; // save mirror copy
					reg_sreg[ZERO_FLAG]							<= result_dff[7:0] == 0 ? 1'b1 : 1'b0;
					reg_sreg[CARRY_FLAG]						<= result_dff[8];
				end
                state										<= FSM_FETCH;
            end
            if (state == FSM_LDM_PART2) begin
				reg_rr[(mask_irq ? 16 : 0) + opcode_opd]	<= bus_data_out[7:0];
				reg_rr2[(mask_irq ? 16 : 0) + opcode_opd]	<= bus_data_out[7:0]; // save mirror copy
				reg_sreg[ZERO_FLAG]							<= bus_data_out[7:0] == 0 ? 1'b1 : 1'b0;
				reg_sreg[CARRY_FLAG]						<= 0;
                state										<= FSM_FETCH;
            end
		end
	end
endmodule
