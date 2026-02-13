`timescale 1ns/1ps

module useq
#(parameter
	FIFO_DEPTH=16,
	ISR_VECT=12'hF0,
	ENABLE_IRQ=1,
	ENABLE_HOST_FIFO_CTRL=1
)(
	input clk,
	input rst_n,
	
	input [15:0] mem_data,				// ROM[mem_addr..mem_addr+1]
	input [7:0] i_port,					// input port you can connect other pins to feed data into the core

	input read_fifo,					// pulse this high to read a byte from the FIFO into fifo_out in the next clock cycle
	input write_fifo,					// pulse this high to write from fifo_in into the FIFO
	output fifo_empty,					// high when the FIFO is empty
	output fifo_full,					// high when the FIFO is full
	input [7:0] fifo_in,				// The FIFO input into the core when pulsing write_fifo 
	output reg [7:0] fifo_out,			// The fifo output from the core when pulsing read_fifo
	
	output reg [11:0] mem_addr,			// The address the core needs mem_data from in the next clock cycle
	output reg [7:0] o_port,			// output port you can connect other pins to feed data out of the core.
	output reg o_port_pulse				// This pin toggles when a write to o_port is done.
);

	reg [7:0] A;								// A accumulator
	reg [7:0] tA;								// temporaty A used for IRQ
	reg [7:0] tR[1:0];							// temporary R[0..1] used for IRQ
	reg [11:0] PC;								// PC program counter
	reg [8:0] T;								// T temporary register used for WAITA opcode
	reg [11:0] LR;								// LR link register
	reg [11:0] ILR;								// ILR IRQ link register
	reg [7:0] instruct;							// current opcode
	reg [7:0] R[15:0];							// R register file
	reg [7:0] l_i_port;							// latched copy of i_port
	reg [7:0] int_mask;							// The IRQ mask applied to i_port set by SEI opcode
	reg [11:0] isr_vect;						// Where to jump when an IRQ happens
	reg int_enable;								// Interrupt enable (set by SEI, disabled during IRQ)
	reg [7:0] FIFO[FIFO_DEPTH-1:0];				// Message passing FIFO
	reg [$clog2(FIFO_DEPTH)-1:0] fifo_rptr;		// FIFO read pointer
	reg [$clog2(FIFO_DEPTH)-1:0] fifo_wptr;		// FIFO write pointer
	reg [2:0] state;							// current FSM state

	localparam
		FETCH=0,
		EXECUTE=1,
		EXECUTE2=2,
		LOADA=3,
		STOREA=4;

	integer i;

	// exec1 wires
	wire [3:0] d_imm = instruct[3:0];
	wire [2:0] s_imm = instruct[3:1];
	wire       b_imm = instruct[0];
	

	wire		int_triggered = |((i_port & ~l_i_port) & int_mask) & int_enable & (ENABLE_IRQ ? 1'b1 : 1'b0);
	wire 		host_wants_fifo = read_fifo ^ write_fifo;
	assign		fifo_empty = (R[15] == 0) ? 1'b1 : 1'b0;
	assign		fifo_full = (R[15] == FIFO_DEPTH) ? 1'b1 : 1'b0;

	// can_chain = 1 means "Single-Cycle Turbo is GO"
	// can_chain = 0 means "Wait, we need a FETCH cycle to realign"
	wire can_chain_exec1 = !(
		(instruct[7:4] == 4'h8) || // IMM form opcodes
		(instruct[7:4] == 4'hA) || // CALL
		(instruct[7:4] == 4'hB) || // JMP
		(instruct[7:4] == 4'hC) || // JZ
		(instruct[7:4] == 4'hD) || // JNZ
		(instruct[7:4] == 4'hE && instruct[3:0] >= 4'h7) || // HLT, SAI, SEI, *RET, *RTI, *WAITs, *EXEC2, *WAITF, *WAITA
		(instruct[7:4] == 4'hF)    // *SBIT
	);
	
	always @(posedge clk) begin
		if (!rst_n) begin
			if (ENABLE_IRQ == 1) begin
				tA <= 0;
				tR[0] <= 0;
				tR[1] <= 0;
				ILR <= 0;
				int_mask <= 0;
				int_enable <= 0;
				isr_vect <= ISR_VECT;
			end
			A <= 0;
			PC <= 0;
			T <= 0;
			LR <= 0;
			state <= FETCH;
			l_i_port <= 0;
			o_port <= 0;
			instruct <= 0;
			mem_addr <= 0;
			o_port_pulse <= 0;
			for (i=0; i<16; i=i+1) begin
				R[i] <= 0;
			end
			for (i=0; i<FIFO_DEPTH; i=i+1) begin
				FIFO[i] <= 0;
			end
			fifo_rptr <= 0;
			fifo_wptr <= 0;
			fifo_out <= 0;
		end else begin
			if (ENABLE_HOST_FIFO_CTRL == 1 && host_wants_fifo) begin
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
				if (int_triggered) begin
					// we hit an interrupt, so disable further interrupts until an RTI
					int_enable <= 0;
					ILR <= PC;     			// save where we interrupted
					tA <= A;
					tR[0] <= R[0];
					tR[1] <= R[1];
					mem_addr <= isr_vect;	// jump to ISR vector
					PC <= isr_vect;
					state <= FETCH;			// need another FETCH cycle
				end else begin
					case(state)
						FETCH:
							begin
								instruct <= mem_data[7:0];
								state <= EXECUTE;
								mem_addr <= PC + 1'b1; // FETCH PC+1 for the EXECUTE stage so we can latch it for a potential EXECUTE2 stage
							end
						EXECUTE:
							begin
								// no interrupt so jump here
								`include "exec1_top.v"
//								$display("for opcode instruct=%2h chain=%d", instruct, can_chain_exec1);
								if (can_chain_exec1) begin
									PC <= PC + 1'b1;			// advance to next PC
									mem_addr <= PC + 12'd2;		// load what will be the "next opcode" in the next cycle
									instruct <= mem_data[7:0];   	// latch the current "next opcode"
									state <= EXECUTE;
								end
							end
						LOADA: // mem_addr was set to the address we want to load and store in A
							begin
								A <= mem_data[7:0];
								mem_addr <= PC;
								state <= FETCH;
							end
						STOREA: // Cycle after a store is initiated
							begin
								// TODO: turn off write enable
								mem_addr <= PC;
								state <= FETCH;
							end
					endcase
				end
			end
		end
	end
endmodule

