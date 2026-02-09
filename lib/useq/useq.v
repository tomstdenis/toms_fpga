`timescale 1ns/1ps

module useq(
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
	reg [7:0] instruct;
	reg [7:0] R[15:0];
	reg [1:0] state;
	reg [7:0] l_i_port;
	reg [7:0] int_mask;

	localparam
		FETCH=0,
		EXECUTE=1,
		LOADA=2;

	integer i;
	
	wire [3:0] d_imm = instruct[3:0];
	wire [2:0] s_imm = instruct[3:1];
	wire       b_imm = instruct[0];

	always @(posedge clk) begin
		if (!rst_n) begin
			A <= 0;
			PC <= 0;
			T <= 0;
			state <= FETCH;
			l_i_port <= 0;
			for (i=0; i<16; i=i+1) begin
				R[i] <= 0;
			end
		end else begin
			l_i_port <= i_port;
			case(state)
				FETCH:
					begin
						instruct <= mem_data;
						state <= EXECUTE;
					end
				EXECUTE:
					begin
						case(instruct[7:4])
							4'h0: // LD R[r]
								begin
									A <= R[d_imm];
									PC <= PC + 1'b1;
									mem_addr <= PC + 1'b1;
									state <= FETCH;
								end
							4'h1: // ST R[r]
								begin
									R[d_imm] <= A;
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
									PC <= PC + d_imm + 1'b1;
									mem_addr <= PC + d_imm + 1'b1;
									state <= FETCH;
								end
							4'h9: // JNZ r
								begin
									if (A == 0) begin
										PC <= PC + 1'b1;
										mem_addr <= PC + 1'b1;
										state <= FETCH;
									end else begin
										PC <= PC - d_imm - 1'b1;
										mem_addr <= PC - d_imm - 1'b1;
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
												mem_addr <= A;
												state <= LOADA;
											end
										4'hB: // SIGT
											begin
												if (A > R[0]) begin
													PC <= PC + 2;
													mem_addr <= PC + 2;
												end else begin
													PC <= PC + 1;
													mem_addr <= PC + 1;
												end
												state <= FETCH;
											end
										4'hC: // SIEQ
											begin
												if (A == R[0]) begin
													PC <= PC + 2;
													mem_addr <= PC + 2;
												end else begin
													PC <= PC + 1;
													mem_addr <= PC + 1;
												end
												state <= FETCH;
											end
										4'hD: // SILT
											begin
												if (A < R[0]) begin
													PC <= PC + 2;
													mem_addr <= PC + 2;
												end else begin
													PC <= PC + 1;
													mem_addr <= PC + 1;
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
							4'hD: // I/O opcoes
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
												end
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
												end
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
												end
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
												R[15] <= PC + 1'b1;
												PC <= A;
												mem_addr <= A;
												state <= FETCH;
											end
										4'h7: // RET
											begin
												PC <= R[15];
												mem_addr <= R[15];
												state <= FETCH;
											end
										4'h8: // SEI
											begin
												int_mask <= A;
												PC <= PC + 1;
												mem_addr <= PC + 1;
												state <= FETCH;
											end
										4'h9: // RTI
											begin
												// todo: re-enable interrupts
												PC <= R[14];
												mem_addr <= R[14];
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
												PC <= PC + 1;
												mem_addr <= PC + 1;
												state <= FETCH;
											end
										4'hD: // ABS
											begin
												A <= A[7] ? (~A + 1'b1) : A;
												PC <= PC + 1;
												mem_addr <= PC + 1;
												state <= FETCH;
											end
										4'hE: // NEG
											begin
												A <= ~A + 1'b1;
												PC <= PC + 1;
												mem_addr <= PC + 1;
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
									PC <= PC + 1'b1 + ((((A >> s_imm) & 1'b1) == b_imm) ? 1'b1 : 1'b0);
									mem_addr <= PC + 1'b1 + ((((A >> s_imm) & 1'b1) == b_imm) ? 1'b1 : 1'b0);
									state <= FETCH;
								end
						endcase
					end
				LOADA:
					begin
						A <= mem_data;
						PC <= PC + 1'b1;
						mem_addr <= PC + 1'b1;
						state <= FETCH;
					end
				default:
					begin
					end
			endcase
		end
	end
endmodule

