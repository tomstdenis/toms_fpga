`timescale 1ns/1ps

module ib16 #(
    parameter STACK_ADDRESS = 16'h1F00,
    parameter IRQ_VECTOR    = 16'h1E00,
    parameter TWO_CYCLE     = 0              // this adds an ALU cycle can be useful to help routing and/or timing
) (
	input clk,
	input rst_n,
	
	// bus signals
    output reg bus_burst,
	output reg bus_enable,
	output reg bus_wr_en,
	output [15:0] bus_address, 
	output reg [15:0] bus_data_in,
	input bus_ready,
	input [15:0] bus_data_out,
	input bus_irq
);

`ifdef SIM
	reg [31:0] stats_cycles;
	reg [31:0] stats_fetches;
`endif

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
    reg [7:0]   reg_irq_sreg;
	reg [7:0]	reg_wi;								// WI (write index)
	reg [7:0]	reg_ri;								// RI (read index)
	reg [7:0]	reg_rr [0:15];						// GPRs 
	reg [7:0]	reg_ra;
	reg [7:0]	reg_rb;
    reg [3:0]   buffer_cnt;
	
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
	reg [8:0]	result_dff;							// the value to be retired
	
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
		OPCODE_LDI = 0,
		OPCODE_ADD = 1,
		OPCODE_ADC = 2,
		OPCODE_SUB = 3,
		OPCODE_XOR = 4,
		OPCODE_AND = 5,
		OPCODE_OR  = 6,
		OPCODE_SHF = 7,
		OPCODE_LDM = 8,
		OPCODE_STM = 9,
		OPCODE_UNK = 10,
		OPCODE_LCAL = 11,
		OPCODE_RET = 12,
		OPCODE_JMP = 13,
		OPCODE_SRS = 14,
		OPCODE_RTI = 15;
	
	localparam
		FSM_FETCH		= 0,				// FETCH next opcode (this should be 0 so we can use nice resets on the state DFFs)
		FSM_PREDECODE	= 1,
		FSM_RETIRE		= 2,
		FSM_BUFFER      = 3,
		FSM_DECODE		= 4; // FSM_DECODE must be the last since we add the opcode_isn to it

	// ALU
	always @(*) begin
		result_dff = {9'b0}; // default no-op
		if (opcode_isn == OPCODE_LDI) begin
			result_dff	= {1'b0, opcode_8imm};
		end
		if (opcode_isn == OPCODE_ADD || opcode_isn == OPCODE_ADC || opcode_isn == OPCODE_SUB) begin
			result_dff	= {{1'b0, reg_ra} +
						   (opcode_isn == OPCODE_SUB ? 
								{1'b0, -reg_rb} :
								{1'b0, reg_rb}) +
						   {8'b0, ((opcode_isn == OPCODE_ADC ? 1'b1 : 1'b0) & carry_flag)}};
		end
		if (opcode_isn == OPCODE_XOR) begin
			result_dff	= {1'b0, reg_ra ^ reg_rb};
		end
		if (opcode_isn == OPCODE_AND) begin
			result_dff	= {1'b0, reg_ra & reg_rb};
		end
		if (opcode_isn == OPCODE_OR) begin
			result_dff	= {1'b0, reg_ra | reg_rb};
		end
		if (opcode_isn == OPCODE_SHF) begin
			case(opcode_opa[2:0])
				0: // SHR
					result_dff = {2'b0, reg_rb[7:1]};
				1: // SAR
					result_dff = {1'b0, reg_rb[7], reg_rb[7:1]};
				2: // ROR
					result_dff = {reg_rb[0], reg_rb[0], reg_rb[7:1]};
				3: // ROL
					result_dff = {reg_rb[7], reg_rb[6:0], reg_rb[7]};
				4: // SWAP
					result_dff = {1'b0, reg_rb[3:0], reg_rb[7:4]};
				5: // INC
					result_dff = {1'b0, reg_rb} + 1'b1;
				6: // DEC
					result_dff = {1'b0, reg_rb} - 1'b1;
				7: // NOT
					result_dff = {1'b0, ~reg_rb};
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
            bus_burst       <= 0;
`ifdef SIM
			stats_cycles	<= 0;
			stats_fetches	<= 0;
`endif
		end else begin
`ifdef SIM
			stats_cycles 	<= stats_cycles + 1'b1;
`endif
            if (state == FSM_BUFFER) begin   // buffer stage to help with ALU critical path timing
                if (buffer_cnt == 0) begin
                    state <= FSM_RETIRE;
                end else begin
                    buffer_cnt <= buffer_cnt - 1'b1;
                end
            end
            if (state == FSM_FETCH) begin
                if (bus_irq && !mask_irq && !bus_enable) begin
                    reg_irq_pc	    <= {reg_pc[15:1], 1'b0}; // force LSB to zero in case we IRQ in the middle of a fetch
                    reg_irq_sreg    <= reg_sreg;
                    mask_irq 	    <= 1;
                    reg_pc	 	    <= IRQ_VECTOR;
                    fsm_cycle	    <= 0;
                end else begin
                    if (!bus_enable) begin
                        bus_enable		  <= 1'b1;
                        bus_address_terma <= reg_pc;		        // read from PC
                        bus_address_termb <= 0;
                        bus_burst         <= 1'b1;              // read 16-bits
                        reg_pc			  <= reg_pc + 16'd2;		// increment PC
                    end
                    if (bus_enable && bus_ready) begin
`ifdef SIM
						stats_fetches 	<= stats_fetches + 1'b1;
`endif
                        cur_opcode  <= bus_data_out;
                        bus_enable  <= 0;
                        bus_burst   <= 0;
                        reg_ra		<= reg_rr[bus_data_out[7:4]];
                        reg_rb		<= reg_rr[bus_data_out[3:0]];
                        buffer_cnt  <= 0; // bus_data_out[15:12] == OPCODE_MUL ? 4 : 0;
                        state		<= (bus_data_out[15:12] <= OPCODE_SHF) ? (TWO_CYCLE == 1 ? FSM_BUFFER : FSM_RETIRE): FSM_DECODE + {2'b0, bus_data_out[15:12]};
                   end
                end
            end
            if (state == FSM_DECODE + OPCODE_LDM) begin
                if (!bus_enable) begin
                    bus_enable			  <= 1;
                    if (opcode_opa == 15 && opcode_opb == 15) begin
                        // pop
                        bus_address_terma <= STACK_ADDRESS;
                        bus_address_termb <= reg_sp - 1'b1;
                        reg_sp			  <= reg_sp - 8'b1;
                    end else begin
                        // load from memory
                        bus_address_terma <= {reg_ra, reg_rb};
                        bus_address_termb <= (reg_sreg[READ_INCR] ? reg_ri : 8'b0);
                        reg_ri			  <= reg_ri + 8'b1;
                    end
                end
                if (bus_enable && bus_ready) begin
                    bus_enable              <= 0;
                    reg_rr[opcode_opd]	    <= bus_data_out[7:0];
                    reg_sreg[ZERO_FLAG]		<= bus_data_out[7:0] == 0 ? 1'b1 : 1'b0;
                    reg_sreg[CARRY_FLAG]	<= 0;
                    state					<= FSM_FETCH;
                end
            end
            if (state == FSM_DECODE + OPCODE_STM) begin
                if (!bus_enable) begin
                    bus_enable			<= 1;
                    bus_wr_en			<= 1;
                    bus_data_in[7:0]	<= reg_rr[opcode_opd];
                    if (opcode_opa == 15 && opcode_opb == 15) begin
                        // push
                        bus_address_terma <= STACK_ADDRESS;
                        bus_address_termb <= reg_sp;
                        reg_sp			  <= reg_sp + 8'b1;
                    end else begin
                        // store to memory
                        bus_address_terma <= {reg_ra, reg_rb};
                        bus_address_termb <= (reg_sreg[WRITE_INCR] ? reg_wi : 8'b0);
                        reg_wi			  <= reg_wi + 8'b1;
                    end
                end
                if (bus_enable && bus_ready) begin
                    bus_enable  <= 0;
                    bus_wr_en   <= 0;
                    state       <= FSM_FETCH;
                end
            end
            if (state == FSM_DECODE + OPCODE_LCAL) begin
                if (!bus_enable) begin
                    bus_enable		<= 1;
                    bus_burst       <= 1;
                    bus_wr_en		<= 1;
                    bus_address_terma <= STACK_ADDRESS;
                    bus_address_termb <= reg_sp;
                    bus_data_in     <= reg_pc;
                    reg_sp			<= reg_sp + 8'd2;
                end
                if (bus_enable && bus_ready) begin
                    state			<= FSM_FETCH;
                    reg_pc		    <= {opcode_12imm, 4'b0};
                    bus_enable      <= 0;
                    bus_burst       <= 0;
                    bus_wr_en       <= 0;
                end
            end
            if (state == FSM_DECODE + OPCODE_RTI) begin
                mask_irq 			<= 0;
                reg_pc	 			<= reg_irq_pc + 16'd2;
                reg_sreg            <= reg_irq_sreg;
				bus_enable		    <= 1'b1;
                bus_address_terma   <= reg_irq_pc;
				bus_address_termb   <= 0;
				bus_burst           <= 1'b1;              // read 16-bits
                state				<= FSM_FETCH;
            end
            if (state == FSM_DECODE + OPCODE_RET) begin
                if (!bus_enable) begin 
                    bus_enable		  <= 1;
                    bus_burst         <= 1;
                    bus_address_terma <= STACK_ADDRESS;
                    bus_address_termb <= reg_sp - 8'd2;
                    reg_sp		      <= reg_sp - 8'd2;
                end
                if (bus_enable && bus_ready) begin
                    bus_enable      <= 0;
                    bus_burst       <= 0;
                    state           <= FSM_FETCH;
                    reg_pc          <= bus_data_out;
                end
            end
            if (state == FSM_DECODE + OPCODE_JMP) begin
                if ((opcode_3imm == 0) ||                           // JMP
                    (opcode_3imm == 1 && carry_flag) ||             // JC
                    (opcode_3imm == 2 && ~carry_flag) ||            // JNC
                    (opcode_3imm == 3 && zero_flag) ||              // JZ
                    (opcode_3imm == 4 && ~zero_flag)) begin         // JNZ
                    reg_pc <= reg_pc + opcode_9simm;

                    // kick start next fetch in this cycle
                    bus_address_terma <= reg_pc + opcode_9simm;		        // read from PC
                    reg_pc			  <= reg_pc + opcode_9simm + 16'd2;		// increment PC				
                end else begin
                    // kick start next fetch in this cycle
                    bus_address_terma <= reg_pc;		        // read from PC
                    reg_pc			  <= reg_pc + 16'd2;		// increment PC				
                end
				bus_enable		  <= 1'b1;
				bus_address_termb <= 0;
				bus_burst         <= 1'b1;              // read 16-bits
                state             <= FSM_FETCH;
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
                reg_rr[opcode_opd]	    <= result_dff[7:0];
                reg_sreg[ZERO_FLAG]		<= result_dff[7:0] == 0 ? 1'b1 : 1'b0;
                reg_sreg[CARRY_FLAG]	<= result_dff[8];
                state					<= FSM_FETCH;

				// kick start next fetch in this cycle
                if (bus_irq && !mask_irq && !bus_enable) begin
                    reg_irq_pc	    <= {reg_pc[15:1], 1'b0}; // force LSB to zero in case we IRQ in the middle of a fetch
                    reg_irq_sreg    <= {result_dff[8], result_dff[7:0] == 0 ? 1'b1 : 1'b0, reg_sreg[5:0]};
                    mask_irq 	    <= 1;
                    reg_pc	 	    <= IRQ_VECTOR + 16'd2;
                    bus_address_terma <= IRQ_VECTOR;		        // read from PC
                end else begin
                    bus_address_terma <= reg_pc;		        // read from PC
                    reg_pc			  <= reg_pc + 16'd2;		// increment PC				
                end
				bus_enable		  <= 1'b1;
				bus_address_termb <= 0;
				bus_burst         <= 1'b1;              // read 16-bits
            end
		end
	end
endmodule
