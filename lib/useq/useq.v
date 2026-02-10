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
					begin
						case(instruct[7:4])
							4'h0: // LD R[r]
								begin
									if (d_imm < 15) begin
										A <= R[d_imm];							// regular register load
									end else begin
										if (R[15] > 0) begin
											// if FIFO isn't empty read from it 
											A <= FIFO[fifo_rptr];				// read fifo data
											R[15] <= R[15] - 1'b1;				// decrement fifo count
											fifo_rptr <= fifo_rptr + 1'b1;		// increment read pointer
										end else begin
											// otherwise read a 0
											A <= 8'b0;
										end
									end
									PC <= PC + 1'b1;
									mem_addr <= PC + 1'b1;
									state <= FETCH;
								end
							4'h1: // ST R[r]
								begin
									if (d_imm < 15) begin
										R[d_imm] <= A;							// regular register store
									end else begin
										if (R[15] < (FIFO_DEPTH-1)) begin
											FIFO[fifo_wptr] <= A;				// store fifo data
											fifo_wptr <= fifo_wptr + 1'b1;		// increment write pointer
											R[15] <= R[15] + 1'b1;				// increment fifo count
										end
									end
									PC <= PC + 1'b1;
									mem_addr <= PC + 1'b1;
									state <= FETCH;
								end
							4'h2: // SETB s, b
								begin
									case(s_imm)
										3'd0: A[0] <= b_imm;
										3'd1: A[1] <= b_imm;
										3'd2: A[2] <= b_imm;
										3'd3: A[3] <= b_imm;
										3'd4: A[4] <= b_imm;
										3'd5: A[5] <= b_imm;
										3'd6: A[6] <= b_imm;
										3'd7: A[7] <= b_imm;
									endcase
									PC <= PC + 1'b1;
									mem_addr <= PC + 1'b1;
									state <= FETCH;
								end
							4'h3: // ADD R[r]
								begin
									A <= A + R[d_imm];
									PC <= PC + 1'b1;
									mem_addr <= PC + 1'b1;
									state <= FETCH;
								end
							4'h4: // SUB R[r]
								begin
									A <= A - R[d_imm];
									PC <= PC + 1'b1;
									mem_addr <= PC + 1'b1;
									state <= FETCH;
								end
							4'h5: // EOR R[r]
								begin
									A <= A ^ R[d_imm];
									PC <= PC + 1'b1;
									mem_addr <= PC + 1'b1;
									state <= FETCH;
								end
							4'h6: // AND R[r]
								begin
									A <= A & R[d_imm];
									PC <= PC + 1'b1;
									mem_addr <= PC + 1'b1;
									state <= FETCH;
								end
							4'h7: // OR R[r]
								begin
									A <= A | R[d_imm];
									PC <= PC + 1'b1;
									mem_addr <= PC + 1'b1;
									state <= FETCH;
								end
							4'h8: // JMP r
								begin
									PC <= PC + {4'b0, d_imm} + 1'b1;
									mem_addr <= PC + {4'b0, d_imm} + 1'b1;
									state <= FETCH;
								end
							4'h9: // JNZ r
								begin
									if (A == 0) begin
										PC <= PC + 1'b1;
										mem_addr <= PC + 1'b1;
										state <= FETCH;
									end else begin
										PC <= PC - {4'b0, d_imm} - 1'b1;
										mem_addr <= PC - {4'b0, d_imm} - 1'b1;
										state <= FETCH;
									end
								end
							4'hA: // ALU opcodes
								begin
									case(instruct[3:0])
										4'h0: // INC
											begin
												A <= A + 1'b1;
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
										4'h1: // DEC
											begin
												A <= A - 1'b1;
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
										4'h2: // ASL
											begin
												A <= A << 1;
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
										4'h3: // LSR
											begin
												A <= A >> 1;
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
										4'h4: // ASR
											begin
												A <= {A[7],A[7:1]};
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
										4'h5: // SWAP
											begin
												A <= {A[3:0], A[7:4]};
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
										4'h6: // ROL
											begin
												A <= {A[6:0], A[7]};
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
										4'h7: // ROR
											begin
												A <= {A[0],A[7:1]};
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
										4'h8: // SWAPR0
											begin
												A <= R[0];
												R[0] <= A;
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
										4'h9: // SWAPR1
											begin
												A <= R[1];
												R[1] <= A;
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
										4'hA: // LDA
											begin
												A <= mem_data;
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
										4'hB: // SIGT
											begin
												if (A > R[0]) begin
													PC <= PC + 8'd2;
													mem_addr <= PC + 8'd2;
												end else begin
													PC <= PC + 1'b1;
													mem_addr <= PC + 1'b1;
												end
												state <= FETCH;
											end
										4'hC: // SIEQ
											begin
												if (A == R[0]) begin
													PC <= PC + 8'd2;
													mem_addr <= PC + 8'd2;
												end else begin
													PC <= PC + 1'b1;
													mem_addr <= PC + 1'b1;
												end
												state <= FETCH;
											end
										4'hD: // SILT
											begin
												if (A < R[0]) begin
													PC <= PC + 8'd2;
													mem_addr <= PC + 8'd2;
												end else begin
													PC <= PC + 1'b1;
													mem_addr <= PC + 1'b1;
												end
												state <= FETCH;
											end
										4'hE: // NOT
											begin
												A <= ~A;
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
										4'hF: // CLR
											begin
												A <= 8'b0;
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
									endcase
								end
							4'hB: // LDIB
								begin
									A[3:0] <= d_imm;
									PC <= PC + 1'b1;
									mem_addr <= PC + 1'b1;
									state <= FETCH;
								end
							4'hC: // LDIT
								begin
									A[7:4] <= d_imm;
									PC <= PC + 1'b1;
									mem_addr <= PC + 1'b1;
									state <= FETCH;
								end
							4'hD: // I/O opcodes
								begin
									case(instruct[3:0])
										4'h0: // OUT
											begin
												o_port <= A;
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
										4'h1: // OUTBIT
											begin
												case(R[0][2:0])
													3'd0: o_port[0] <= A[0];
													3'd1: o_port[1] <= A[0];
													3'd2: o_port[2] <= A[0];
													3'd3: o_port[3] <= A[0];
													3'd4: o_port[4] <= A[0];
													3'd5: o_port[5] <= A[0];
													3'd6: o_port[6] <= A[0];
													3'd7: o_port[7] <= A[0];
												endcase
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
										4'h2: // TGLBIT
											begin
												case(R[1][2:0])
													3'd0: o_port[0] <= o_port[0] ^ 1;
													3'd1: o_port[1] <= o_port[1] ^ 1;
													3'd2: o_port[2] <= o_port[2] ^ 1;
													3'd3: o_port[3] <= o_port[3] ^ 1;
													3'd4: o_port[4] <= o_port[4] ^ 1;
													3'd5: o_port[5] <= o_port[5] ^ 1;
													3'd6: o_port[6] <= o_port[6] ^ 1;
													3'd7: o_port[7] <= o_port[7] ^ 1;
												endcase
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
										4'h3: // IN
											begin
												A <= l_i_port;
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
										4'h4: // INBIT
											begin
												case(R[0][2:0])
													3'd0: A <= l_i_port[0] ? 1 : 0;
													3'd1: A <= l_i_port[1] ? 1 : 0;
													3'd2: A <= l_i_port[2] ? 1 : 0;
													3'd3: A <= l_i_port[3] ? 1 : 0;
													3'd4: A <= l_i_port[4] ? 1 : 0;
													3'd5: A <= l_i_port[5] ? 1 : 0;
													3'd6: A <= l_i_port[6] ? 1 : 0;
													3'd7: A <= l_i_port[7] ? 1 : 0;
												endcase
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
										4'h5: // JMP
											begin
												PC <= A;
												mem_addr <= A;
												state <= FETCH;
											end
										4'h6: // CALL
											begin
												LR <= PC + 1'b1;
												PC <= A;
												mem_addr <= A;
												state <= FETCH;
											end
										4'h7: // RET
											begin
												PC <= LR;
												mem_addr <= LR;
												state <= FETCH;
											end
										4'h8: // SEI
											begin
												int_mask <= A;
												int_enable <= (A == 0) ? 1'b0 : 1'b1;
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
										4'h9: // RTI
											begin
												int_enable <= 1;	// restore interrupt enabled
												PC <= ILR;
												mem_addr <= ILR;
												state <= FETCH;
											end
										4'hA: // WAIT0
											begin
												state <= FETCH;
												case(R[1][2:0])
													3'd0: begin PC <= PC - (l_i_port[0] + 8'hFF); mem_addr <= mem_addr - (l_i_port[0] + 8'hFF); end
													3'd1: begin PC <= PC - (l_i_port[1] + 8'hFF); mem_addr <= mem_addr - (l_i_port[1] + 8'hFF); end
													3'd2: begin PC <= PC - (l_i_port[2] + 8'hFF); mem_addr <= mem_addr - (l_i_port[2] + 8'hFF); end
													3'd3: begin PC <= PC - (l_i_port[3] + 8'hFF); mem_addr <= mem_addr - (l_i_port[3] + 8'hFF); end
													3'd4: begin PC <= PC - (l_i_port[4] + 8'hFF); mem_addr <= mem_addr - (l_i_port[4] + 8'hFF); end
													3'd5: begin PC <= PC - (l_i_port[5] + 8'hFF); mem_addr <= mem_addr - (l_i_port[5] + 8'hFF); end
													3'd6: begin PC <= PC - (l_i_port[6] + 8'hFF); mem_addr <= mem_addr - (l_i_port[6] + 8'hFF); end
													3'd7: begin PC <= PC - (l_i_port[7] + 8'hFF); mem_addr <= mem_addr - (l_i_port[7] + 8'hFF); end
												endcase
											end
										4'hB: // WAIT1
											begin
												state <= FETCH;
												case(R[1][2:0])
													3'd0: begin PC <= PC + l_i_port[0]; mem_addr <= mem_addr + l_i_port[0]; end
													3'd1: begin PC <= PC + l_i_port[1]; mem_addr <= mem_addr + l_i_port[1]; end
													3'd2: begin PC <= PC + l_i_port[2]; mem_addr <= mem_addr + l_i_port[2]; end
													3'd3: begin PC <= PC + l_i_port[3]; mem_addr <= mem_addr + l_i_port[3]; end
													3'd4: begin PC <= PC + l_i_port[4]; mem_addr <= mem_addr + l_i_port[4]; end
													3'd5: begin PC <= PC + l_i_port[5]; mem_addr <= mem_addr + l_i_port[5]; end
													3'd6: begin PC <= PC + l_i_port[6]; mem_addr <= mem_addr + l_i_port[6]; end
													3'd7: begin PC <= PC + l_i_port[7]; mem_addr <= mem_addr + l_i_port[7]; end
												endcase
											end
										4'hC: // MASK4
											begin
												A <= A & 8'h0F;
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
										4'hD: // WAITF
											begin
												// only advance PC if A == fifo_cnt
												if (R[15] == A) begin
													PC <= PC + 1'b1;
													mem_addr <= PC + 1'b1;
												end else begin
													mem_addr <= PC;
												end
												state <= FETCH;
											end
										4'hE: // NEG
											begin
												A <= ~A + 1'b1;
												PC <= PC + 1'b1;
												mem_addr <= PC + 1'b1;
												state <= FETCH;
											end
										4'hF: // WAITA
											begin
												if (A == 0) begin
													if (T[8]) begin
														A <= T[7:0];
													end
													T <= 0;
													PC <= PC + 1'b1;
													mem_addr <= PC + 1'b1;
												end else begin
													if (!T[8]) begin
														T <= {1'b1, A};
													end
													A <= A - 1'b1;
													mem_addr <= PC;
												end
												state <= FETCH;
											end
									endcase
								end
							4'hE: // JSR
								begin
									PC <= {d_imm, 4'b0};
									mem_addr <= {d_imm, 4'b0};
									state <= FETCH;
								end
							4'hF: // SBIT
								begin
									PC <= PC + 1'b1 + ((((A >> s_imm) & 8'd1) == {7'b0, b_imm}) ? 8'd1 : 8'd0);
									mem_addr <= PC + 1'b1 + ((((A >> s_imm) & 8'd1) == {7'b0, b_imm}) ? 8'd1 : 8'd0);
									state <= FETCH;
								end
						endcase
					end
				default:
					begin
					end
			endcase
		end
	end
endmodule

