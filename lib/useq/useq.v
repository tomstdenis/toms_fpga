`timescale 1ns/1ps

module useq
#(parameter FIFO_DEPTH=4,ISR_VECT=8'hF0)
(
	input clk,
	input rst_n,
	
	input [7:0] mem_data,
	input [7:0] i_port,
	
	output reg [7:0] mem_addr,
	output reg [7:0] o_port
);

	reg [7:0] A;
	reg [7:0] PC;
	reg [8:0] T;
	reg [7:0] LR;
	reg [7:0] ILR;
	reg [7:0] instruct;
	reg [7:0] R[15:0];
	reg [1:0] state;
	reg [7:0] l_i_port;
	reg [7:0] int_mask;
	reg int_enable;
	reg [7:0] FIFO[FIFO_DEPTH-1:0];
	reg [$clog2(FIFO_DEPTH)-1:0] fifo_rptr;
	reg [$clog2(FIFO_DEPTH)-1:0] fifo_wptr;

	localparam
		FETCH=0,
		EXECUTE=1,
		LOADA=2;

	integer i;
	
	wire [3:0] d_imm = instruct[3:0];
	wire [2:0] s_imm = instruct[3:1];
	wire       b_imm = instruct[0];
	wire       int_triggered = |((i_port & ~l_i_port) & int_mask) & int_enable;

	always @(posedge clk) begin
		if (!rst_n) begin
			A <= 0;
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
			for (i=0; i<16; i=i+1) begin
				R[i] <= 0;
			end
			for (i=0; i<FIFO_DEPTH; i=i+1) begin
				FIFO[i] <= 0;
			end
			fifo_rptr <= 0;
			fifo_wptr <= 0;
			o_port <= 0;
		end else begin
			l_i_port <= i_port;
			case(state)
				FETCH:
					begin
						if (int_triggered) begin
							// we hit an interrupt, so disable further interrupts until an RTI
							int_enable <= 0;
							ILR <= PC;     			// save where we interrupted
							mem_addr <= ISR_VECT;	// jump to ISR vector
							PC <= 8'hF0;
							state <= FETCH;			// need another FETCH cycle
						end else begin
							instruct <= mem_data;
							state <= EXECUTE;
							if (mem_data == 8'hAA) begin // LDA instruction reads from ROM
								mem_addr <= A;
							end else begin
								mem_addr <= mem_addr + 1'b1; // FETCH PC+1 for the EXECUTE stage so we can latch it for a potential EXECUTE2 stage
							end
						end
					end
				EXECUTE:
`include "exec1_top.v"
				default:
					begin
					end
			endcase
		end
	end
endmodule

