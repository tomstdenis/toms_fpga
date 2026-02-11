// This is the top of the EXECUTE1 case statement in the FSM
begin
	case(instruct[7:4])
		4'h0: // LD R[r]
			begin
				if (d_imm < 15) begin
					A <= R[d_imm];							// regular register load
				end else begin
					// LD from R[15] means read from the FIFO
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
			end
		4'h1: // ST R[r]
			begin
				if (d_imm < 15) begin
					R[d_imm] <= A;							// regular register store
				end else begin
					if (R[15] != FIFO_DEPTH) begin
						FIFO[fifo_wptr] <= A;				// store fifo data
						fifo_wptr <= fifo_wptr + 1'b1;		// increment write pointer
						R[15] <= R[15] + 1'b1;				// increment fifo count
					end
				end
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
			end
		4'h3: // ADD R[r]
			begin
				A <= A + R[d_imm];
			end
		4'h4: // SUB R[r]
			begin
				A <= A - R[d_imm];
			end
		4'h5: // EOR R[r]
			begin
				A <= A ^ R[d_imm];
			end
		4'h6: // AND R[r]
			begin
				A <= A & R[d_imm];
			end
		4'h7: // OR R[r]
			begin
				A <= A | R[d_imm];
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
						end
					4'h1: // DEC
						begin
							A <= A - 1'b1;
						end
					4'h2: // ASL
						begin
							A <= {A[6:0], 1'b0};
						end
					4'h3: // LSR
						begin
							A <= {1'b0, A[7:1]};
						end
					4'h4: // ASR
						begin
							A <= {A[7],A[7:1]};
						end
					4'h5: // SWAP
						begin
							A <= {A[3:0], A[7:4]};
						end
					4'h6: // ROL
						begin
							A <= {A[6:0], A[7]};
						end
					4'h7: // ROR
						begin
							A <= {A[0],A[7:1]};
						end
					4'h8: // SWAPR0
						begin
							A <= R[0];
							R[0] <= A;
						end
					4'h9: // SWAPR1
						begin
							A <= R[1];
							R[1] <= A;
						end
					4'hA: // NOT
						begin
							A <= ~A;
						end
					4'hB: // CLR
						begin
							A <= 8'b0;
						end
					4'hC: // LDA
						begin
							mem_addr <= A;
							R[14] <= A + 1'b1;
							PC <= PC + 1'b1;
							state <= LOADA;
						end
					4'hD: // SIGT
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
					4'hE: // SIEQ
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
					4'hF: // SILT
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
				endcase
			end
		4'hB: // LDIB
			begin
				A[3:0] <= d_imm;
			end
		4'hC: // LDIT
			begin
				A[7:4] <= d_imm;
			end
		4'hD: // I/O opcodes
			begin
				case(instruct[3:0])
					4'h0: // OUT
						begin
							o_port <= A;
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
						end
					4'h3: // IN
						begin
							A <= l_i_port;
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
						end
					4'h5: // NEG
						begin
							A <= ~A + 1'b1;
						end
					4'h6: // SEI
						begin
							if (ENABLE_IRQ == 1) begin
								int_mask <= A;
								int_enable <= (A == 0) ? 1'b0 : 1'b1;
							end
						end
					4'h7: // JMPA
						begin
							PC <= A;
							mem_addr <= A;
							state <= FETCH;
						end
					4'h8: // CALL
						begin
							LR <= PC + 1'b1;
							PC <= A;
							mem_addr <= A;
							state <= FETCH;
						end
					4'h9: // RET
						begin
							PC <= LR;
							mem_addr <= LR;
							state <= FETCH;
						end
					4'hA: // RTI
						begin
							if (ENABLE_IRQ == 1) begin
								int_enable <= 1;	// restore interrupt enabled
								PC <= ILR;
								A <= tA;
								R[0] <= tR[0];
								R[1] <= tR[1];
								mem_addr <= ILR;
								state <= FETCH;
								mode <= prevmode;
							end else begin
								PC <= PC + 1'b1;
								mem_addr <= PC + 1'b1;
								state <= FETCH;
							end
						end
					4'hB: // WAIT0
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
					4'hC: // WAIT1
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
					4'hD: // eventually EXEC2
						begin
							if (ENABLE_EXEC2) begin
								mode <= 1;
							end
							PC <= PC + 1'b1;
							mem_addr <= PC + 1'b1;
							state <= FETCH;							
						end
					4'hE: // WAITF
						begin
							// only advance PC if fifo_cnt >= A
							if (R[15] >= A) begin
								PC <= PC + 1'b1;
								mem_addr <= PC + 1'b1;
							end else begin
								mem_addr <= PC;
							end
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
