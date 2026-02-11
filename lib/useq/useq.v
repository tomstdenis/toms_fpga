`timescale 1ns/1ps

module useq
#(parameter FIFO_DEPTH=16,ISR_VECT=8'hF0,ENABLE_EXEC1=1,ENABLE_EXEC2=1,ENABLE_IRQ=1)
(
	input clk,
	input rst_n,
	
	input [7:0] mem_data,
	input [7:0] i_port,

	input read_fifo,
	input write_fifo,
	output fifo_empty,
	output fifo_full,
	input [7:0] fifo_in,
	output reg [7:0] fifo_out,
	
	output reg [7:0] mem_addr,
	output reg [7:0] o_port
);

	reg [7:0] A;								// A accumulator
	reg [7:0] tA;								// temporaty A used for IRQ
	reg [7:0] tR[1:0];							// temporary R[0..1] used for IRQ
	reg [7:0] PC;								// PC program counter
	reg [8:0] T;								// T temporary register used for WAITA opcode
	reg [7:0] LR;								// LR link register
	reg [7:0] ILR;								// ILR IRQ link register
	reg [7:0] instruct;							// current opcode
	reg [7:0] R[15:0];							// R register file
	reg [3:0] state;							// current FSM state
	reg [7:0] l_i_port;							// latched copy of i_port
	reg [7:0] int_mask;							// The IRQ mask applied to i_port set by SEI opcode
	reg int_enable;								// Interrupt enable (set by SEI, disabled during IRQ)
	reg [7:0] FIFO[FIFO_DEPTH-1:0];				// Message passing FIFO
	reg [$clog2(FIFO_DEPTH)-1:0] fifo_rptr;		// FIFO read pointer
	reg [$clog2(FIFO_DEPTH)-1:0] fifo_wptr;		// FIFO write pointer
	reg mode;									// Current opcode mode (mode == 0 means EXEC1, mode == 1 means EXEC2)
	reg prevmode;								// previous mode used for handling IRQs since ISRs have to be EXEC1

	localparam
		FETCH=0,
		EXECUTE=1,
		EXECUTE2=2,
		LOADA=3,
		LOADR=4;

	integer i;

	// exec1 wires
	wire [3:0] d_imm = instruct[3:0];
	wire [2:0] s_imm = instruct[3:1];
	wire       b_imm = instruct[0];
	
	// exec2 wires
	wire [3:0] e2_r = {2'b0, instruct[3:2]};
	wire [3:0] e2_s = {2'b0, instruct[1:0]};
	wire [7:0] e2_s_wire = R[e2_s];
	
	wire       int_triggered = |((i_port & ~l_i_port) & int_mask) & int_enable & (ENABLE_IRQ ? 1'b1 : 1'b0);
	assign fifo_empty = (R[15] == 0) ? 1'b1 : 1'b0;
	assign fifo_full = (R[15] == FIFO_DEPTH) ? 1'b1 : 1'b0;

	// can_chain = 1 means "Single-Cycle Turbo is GO"
	// can_chain = 0 means "Wait, we need a FETCH cycle to realign"
	wire can_chain_exec1 = !(
		(instruct[7:4] == 4'h8) || // *JMP r
		(instruct[7:4] == 4'h9) || // *JNZ r
		(instruct[7:4] == 4'hA && instruct[3:0] >= 4'hC) || // *LDA, *SIGT, *SIEQ, *SILT
		(instruct[7:4] == 4'hD && instruct[3:0] >= 4'h7) || // *JMPA, *CALL, *RET, *RTI, *WAITs, *EXEC2, *WAITF, *WAITA
		(instruct[7:4] == 4'hE) || // *JSR r
		(instruct[7:4] == 4'hF)    // *SBIT
	);
	
	wire can_chain_exec2 = !(
		(instruct[7:4] == 4'h6 && instruct[3:2] == 2'h2) || // LDI
		(instruct[7:4] == 4'h8) || // SIGT
		(instruct[7:4] == 4'h9) || // SIEQ
		(instruct[7:4] == 4'hA) || // SILT
		(instruct[7:4] == 4'hE && instruct[3:2] < 2'h2) || // JNZ, JZ
		(instruct[7:4] == 4'hF && instruct[3:2] < 2'h3) || // JMP, CALL, RET
		(instruct[7:0] == 8'hFF)); // WAITA

	always @(posedge clk) begin
		if (!rst_n) begin
			A <= 0;
			tA <= 0;
			tR[0] <= 0;
			tR[1] <= 0;
			PC <= 0;
			T <= 0;
			LR <= 0;
			ILR <= 0;
			state <= FETCH;
			l_i_port <= 0;
			instruct <= 0;
			int_mask <= 0;
			mem_addr <= 0;
			int_enable <= 0;
			mode <= 0;
			prevmode <= 0;
			for (i=0; i<16; i=i+1) begin
				R[i] <= 0;
			end
			for (i=0; i<FIFO_DEPTH; i=i+1) begin
				FIFO[i] <= 0;
			end
			fifo_rptr <= 0;
			fifo_wptr <= 0;
            fifo_out <= 0;
			o_port <= 0;
		end else begin
			if (read_fifo ^ write_fifo) begin
				if (read_fifo) begin
					// read fifo to o_port
					if (R[15] != 0) begin
						fifo_out <= FIFO[fifo_rptr];
						fifo_rptr <= fifo_rptr + 1'b1;
						R[15] <= R[15] - 1'b1;
					end else begin
						// fifo empty so write 0 to the port
						o_port <= 8'd0;
					end
				end else begin
					if (R[15] != FIFO_DEPTH) begin
						FIFO[fifo_wptr] <= fifo_in;			// store fifo data
						fifo_wptr <= fifo_wptr + 1'b1;		// increment write pointer
						R[15] <= R[15] + 1'b1;				// increment fifo count
					end
				end
			end else begin
				l_i_port <= i_port;						// only latch port when we're running the CPU
				case(state)
					FETCH:
						begin
							if (ENABLE_IRQ == 1 && int_triggered) begin
								// we hit an interrupt, so disable further interrupts until an RTI
								int_enable <= 0;
								ILR <= PC;     			// save where we interrupted
								mem_addr <= ISR_VECT;	// jump to ISR vector
								tA <= A;
								tR[0] <= R[0];
								tR[1] <= R[1];
								PC <= ISR_VECT;
								state <= FETCH;			// need another FETCH cycle
								prevmode <= mode;		// save the execution mode
								mode <= 0;				// go back to ACC mode
							end else begin
								instruct <= mem_data;
								if (ENABLE_EXEC1 == 1 && ENABLE_EXEC2 == 1) begin
									state <= mode ? EXECUTE2 : EXECUTE;
								end else if (ENABLE_EXEC1 == 1) begin
									state <= EXECUTE;
								end else begin
									state <= EXECUTE2;
								end
								mem_addr <= PC + 1'b1; // FETCH PC+1 for the EXECUTE stage so we can latch it for a potential EXECUTE2 stage
							end
						end
					EXECUTE:
						if (ENABLE_EXEC1 == 1) begin
							if (ENABLE_IRQ == 1 && int_triggered) begin
								// we hit an interrupt, so disable further interrupts until an RTI
								int_enable <= 0;
								ILR <= PC;     			// save where we interrupted
								mem_addr <= ISR_VECT;	// jump to ISR vector
								tA <= A;
								tR[0] <= R[0];
								tR[1] <= R[1];
								PC <= ISR_VECT;
								state <= FETCH;			// need another FETCH cycle
								prevmode <= mode;		// save the execution mode
								mode <= 0;				// go back to ACC mode
							end else begin
								// no interrupt so jump here
								`include "exec1_top.v"
								if (can_chain_exec1) begin
									PC <= PC + 1'b1;			// advance to next PC
									mem_addr <= PC + 8'd2;		// load what will be the "next opcode" in the next cycle
									instruct <= mem_data;   // latch the current "next opcode"
									state <= EXECUTE;
								end
							end
						end
					EXECUTE2:
						if (ENABLE_EXEC2 == 1) begin
							if (ENABLE_EXEC1 == 1 && ENABLE_IRQ == 1 && int_triggered) begin		// IRQs require EXEC1 support
								// we hit an interrupt, so disable further interrupts until an RTI
								int_enable <= 0;
								ILR <= PC;     			// save where we interrupted
								mem_addr <= ISR_VECT;	// jump to ISR vector
								tA <= A;
								tR[0] <= R[0];
								tR[1] <= R[1];
								PC <= ISR_VECT;
								state <= FETCH;			// need another FETCH cycle
								prevmode <= mode;		// save the execution mode
								mode <= 0;				// go back to ACC mode
							end else begin
								// no interrupt so jump here
								`include "exec2_top.v"
								if (can_chain_exec2) begin
									PC <= PC + 1'b1;			// advance to next PC
									mem_addr <= PC + 8'd2;		// load what will be the "next opcode" in the next cycle
									instruct <= mem_data;   // latch the current "next opcode"
									state <= EXECUTE2;
								end
							end
						end
					LOADA: // load A with whatever was read from ROM
						begin
							A <= mem_data;
							mem_addr <= PC;
							state <= FETCH;
						end
					default:
						begin
						end
				endcase
			end
		end
	end
endmodule

