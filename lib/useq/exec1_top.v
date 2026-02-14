// This is the top of the EXECUTE1 case statement in the FSM
begin
	case(instruct[7:4])
		4'h0: // LD R[r]
			begin
				if (d_imm != 15) begin
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
				PC <= PC + 12'b1;			// advance to next PC
				mem_addr <= PC + 12'd1;		// load what will be the "next opcode" in the next cycle
				mem_addr_next <= PC + 12'd2;
				state <= FETCH;
			end
		4'h1: // ST R[r]
			begin
				if (d_imm != 15) begin
					R[d_imm] <= A;							// regular register store
				end else begin
					if (R[15] != FIFO_DEPTH) begin
						FIFO[fifo_wptr] <= A;				// store fifo data
						fifo_wptr <= fifo_wptr + 1'b1;		// increment write pointer
						R[15] <= R[15] + 1'b1;				// increment fifo count
					end
				end
				PC <= PC + 12'b1;			// advance to next PC
				mem_addr <= PC + 12'd1;		// load what will be the "next opcode" in the next cycle
				mem_addr_next <= PC + 12'd2;
				state <= FETCH;
			end
		4'h2: // SETB s, b
			begin
				A[s_imm] <= b_imm;
				PC <= PC + 12'b1;			// advance to next PC
				mem_addr <= PC + 12'd1;		// load what will be the "next opcode" in the next cycle
				mem_addr_next <= PC + 12'd2;
				state <= FETCH;
			end
		4'h3: // ADD R[r]
			begin
				A <= A + R[d_imm];
				PC <= PC + 12'b1;			// advance to next PC
				mem_addr <= PC + 12'd1;		// load what will be the "next opcode" in the next cycle
				mem_addr_next <= PC + 12'd2;
				state <= FETCH;
			end
		4'h4: // SUB R[r]
			begin
				A <= A - R[d_imm];
				PC <= PC + 12'b1;			// advance to next PC
				mem_addr <= PC + 12'd1;		// load what will be the "next opcode" in the next cycle
				mem_addr_next <= PC + 12'd2;
				state <= FETCH;
			end
		4'h5: // EOR R[r]
			begin
				A <= A ^ R[d_imm];
				PC <= PC + 12'b1;			// advance to next PC
				mem_addr <= PC + 12'd1;		// load what will be the "next opcode" in the next cycle
				mem_addr_next <= PC + 12'd2;
				state <= FETCH;
			end
		4'h6: // AND R[r]
			begin
				A <= A & R[d_imm];
				PC <= PC + 12'b1;			// advance to next PC
				mem_addr <= PC + 12'd1;		// load what will be the "next opcode" in the next cycle
				mem_addr_next <= PC + 12'd2;
				state <= FETCH;
			end
		4'h7: // OR R[r]
			begin
				A <= A | R[d_imm];
				PC <= PC + 12'b1;			// advance to next PC
				mem_addr <= PC + 12'd1;		// load what will be the "next opcode" in the next cycle
				mem_addr_next <= PC + 12'd2;
				state <= FETCH;
			end
		4'h8: // IMM commands (e.g. LDI, ADDI, etc) we handle chaining here because the other can_chain is only for 1 byte opcodes
			begin
				case(instruct[3:0])
					4'h0: // LDI
						begin
							A <= instruct_imm;
						end
					4'h1: // ADDI
						begin
							A <= A + instruct_imm;
						end
					4'h2: // SUBI
						begin
							A <= A - instruct_imm;
						end
					4'h3: // EORI
						begin
							A <= A ^ instruct_imm;
						end
					4'h4: // ANDI
						begin
							A <= A & instruct_imm;
						end
					4'h5: // ORI
						begin
							A <= A | instruct_imm;
						end
					4'h6: // LDIR0
						begin
							R[0] <= instruct_imm;
						end
					4'h7: // LDIR1
						begin
							R[1] <= instruct_imm;
						end
					4'h8: // LDIR11
						begin
							R[11] <= instruct_imm;
						end
					4'h9: // LDIR12
						begin
							R[12] <= instruct_imm;
						end
					4'hA: // LDIR13
						begin
							R[13] <= instruct_imm;
						end
					4'hB: // LDIR14
						begin
							R[14] <= instruct_imm;
						end
					4'hC: // MUL
						begin
							{R[0], A} <= A * R[0];
							PC <= PC + 12'd1;
							mem_addr <= PC + 12'd1;
							mem_addr_next <= PC + 12'd2;
							state <= FETCH;
						end
					4'hD: // LDM
						begin
							mem_addr <= {R[14][3:0], R[13]};
							{R[14], R[13]} <= {R[14], R[13]} + 1'b1;
							PC <= PC + 12'd1;
							state <= LOADA;
						end
					4'hE: // STM
						begin
							mem_out <= A;								// store A
							mem_addr <= {R[12][3:0], R[11]};			// at R12:R11
							wren <= 1'b1; 								// enable write on memory
							{R[12], R[11]} <= {R[12], R[11]} + 1'b1;	// post increment 
							PC <= PC + 12'd1;
							state <= STOREA;							// wait for write before moving to FETCH
						end
					4'hF: // LDMIND
						begin
							mem_addr <= {R[14][3:0], R[13]} + { 3'b0, A, 1'b0 };		// we're loading a pointer from R14:R13 + A
							mem_addr_next <= {R[14][3:0], R[13]} + { 3'b0, A, 1'b1 };
							PC <= PC + 12'd1;
							state <= LOADIND;
						end
					default:
						begin end
				endcase
				case(instruct[3:0])
					4'hC,4'hD,4'hE,4'hF: // already handled MUL/LDM/STM/LDMIND
						begin end
					default:
						begin
							// IMM opcodes have a payload byte following the actually command
							PC <= PC + 12'd2;
							mem_addr <= PC + 12'd2;		// we prefetch the next next opcode so PC+3
							mem_addr_next <= PC + 12'd3;
							state <= FETCH;
						end
				endcase						
			end
		4'h9: // ALU opcodes
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
					4'hC: // SIGT
						begin
							A <= (A > R[0]) ? 8'd1 : 8'd0;
						end
					4'hD: // SIEQ
						begin
							A <= (A == R[0]) ? 8'd1 : 8'd0;
						end
					4'hE: // SILT
						begin
							A <= (A < R[0]) ? 8'd1 : 8'd0;
						end
					4'hF: // XXX (must be chainable)
						begin
						end
				endcase
				PC <= PC + 12'b1;			// advance to next PC
				mem_addr <= PC + 12'd1;		// load what will be the "next opcode" in the next cycle
				mem_addr_next <= PC + 12'd2;
				state <= FETCH;
			end

		4'hA: // JMP IMM12
			begin
				PC <= {instruct[3:0], instruct_imm};
				mem_addr <= {instruct[3:0], instruct_imm};
				mem_addr_next <= {instruct[3:0], instruct_imm} + 12'd1;
				state <= FETCH;
			end
		4'hB: // CALL IMM12
			begin
				LR <= PC + 12'd2;
				PC <= {instruct[3:0], instruct_imm};
				mem_addr <= {instruct[3:0], instruct_imm};
				mem_addr_next <= {instruct[3:0], instruct_imm} + 12'd1;
				state <= FETCH;
			end
		4'hC: // JZ IMM12
			begin
				if (A == 0) begin
					PC <= {instruct[3:0], instruct_imm};
					mem_addr <= {instruct[3:0], instruct_imm};
					mem_addr_next <= {instruct[3:0], instruct_imm} + 12'd1;
				end else begin
					PC <= PC + 12'd2;
					mem_addr <= PC + 12'd2;
					mem_addr_next <= PC + 12'd3;
				end
				state <= FETCH;
			end
		4'hD: // JNZ IMM12
			begin
				if (A != 0) begin
					PC <= {instruct[3:0], instruct_imm};
					mem_addr <= {instruct[3:0], instruct_imm};
					mem_addr_next <= {instruct[3:0], instruct_imm} + 12'd1;
				end else begin
					PC <= PC + 12'd2;
					mem_addr <= PC + 12'd2;
					mem_addr_next <= PC + 12'd3;
				end
				state <= FETCH;
			end
		4'hE: // I/O opcodes
			begin
				case(instruct[3:0])
					4'h0: // OUT
						begin
							o_port <= A;
							o_port_pulse <= o_port_pulse ^ 1'b1;
							PC <= PC + 12'b1;			// advance to next PC
							mem_addr <= PC + 12'd1;		// load what will be the "next opcode" in the next cycle
							mem_addr_next <= PC + 12'd2;
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
							o_port_pulse <= o_port_pulse ^ 1'b1;
							PC <= PC + 12'b1;			// advance to next PC
							mem_addr <= PC + 12'd1;		// load what will be the "next opcode" in the next cycle
							mem_addr_next <= PC + 12'd2;
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
							o_port_pulse <= o_port_pulse ^ 1'b1;
							PC <= PC + 12'b1;			// advance to next PC
							mem_addr <= PC + 12'd1;		// load what will be the "next opcode" in the next cycle
							mem_addr_next <= PC + 12'd2;
							state <= FETCH;
						end
					4'h3: // IN
						begin
							A <= l_i_port;
							PC <= PC + 12'b1;			// advance to next PC
							mem_addr <= PC + 12'd1;		// load what will be the "next opcode" in the next cycle
							mem_addr_next <= PC + 12'd2;
							state <= FETCH;
						end
					4'h4: // INBIT
						begin
							A <= ((l_i_port >> R[0][2:0]) & 8'b1);
							PC <= PC + 12'b1;			// advance to next PC
							mem_addr <= PC + 12'd1;		// load what will be the "next opcode" in the next cycle
							mem_addr_next <= PC + 12'd2;
							state <= FETCH;
						end
					4'h5: // NEG
						begin
							A <= -A;
							PC <= PC + 12'b1;			// advance to next PC
							mem_addr <= PC + 12'd1;		// load what will be the "next opcode" in the next cycle
							mem_addr_next <= PC + 12'd2;
							state <= FETCH;
						end
					4'h6: // NOP
						begin
							PC <= PC + 12'b1;			// advance to next PC
							mem_addr <= PC + 12'd1;		// load what will be the "next opcode" in the next cycle
							mem_addr_next <= PC + 12'd2;
							state <= FETCH;
						end
					4'h7: // SEI
						begin
							if (ENABLE_IRQ == 1) begin
								int_mask <= instruct_imm;
								PC <= PC + 12'd2;
								mem_addr <=  PC + 12'd2;
								mem_addr_next <= PC + 12'd3;
								state <= FETCH;
								int_enable <= (instruct_imm == 0) ? 1'b0 : 1'b1;
							end
						end
					4'h8: // SAI IMM
						begin
							isr_vect <= {instruct_imm, 4'b0};
							PC <= PC + 12'd2;
							mem_addr <= PC + 12'd2;
							mem_addr_next <= PC + 12'd3;
							state <= FETCH;
						end
					4'h9: // HLT
						begin
							state <= FETCH;
						end
					4'hA: // RET
						begin
							PC <= LR;
							mem_addr <= LR;
							mem_addr_next <= LR + 12'd1;
							state <= FETCH;
						end
					4'hB: // RTI
						begin
							if (ENABLE_IRQ == 1) begin
								int_enable <= 1;	// restore interrupt enabled
								PC <= ILR;			// restore PC
								A <= tA;			// restore A
								R[0] <= tR[0];		// restore R[0] and R[1]
								R[1] <= tR[1];
								T <= tT;			// restore T counter if we interrupted an WAITA
								mem_addr <= ILR;	// fetch instruction we interrupted
								mem_addr_next <= ILR + 12'd1;
								state <= FETCH;		// we need a FETCH cycle to load instruct
							end else begin
								PC <= PC + 1'b1;
								mem_addr <= PC + 1'b1;
								mem_addr_next <= PC + 12'd2;
								state <= FETCH;
							end
						end
					4'hC: // WAIT0
						begin
							if (((l_i_port >> R[1][2:0]) & 8'b1) == 0) begin
								PC <= PC + 1'b1;
								mem_addr <= PC + 12'd1;
								mem_addr_next <= PC + 12'd2;
								state <= FETCH;
							end
						end
					4'hD: // WAIT1
						begin
							if (((l_i_port >> R[1][2:0]) & 8'b1) == 1) begin
								PC <= PC + 1'b1;
								mem_addr <= PC + 12'd1;
								mem_addr_next <= PC + 12'd2;
								state <= FETCH;
							end
						end
					4'hE: // WAITF
						begin
							// only advance PC if fifo_cnt >= A
							if (R[15] >= A) begin
								PC <= PC + 1'b1;			// FIFO has enough contents advance to the next
								mem_addr <= PC + 12'd1;		// we're chaining so we need to tell the ROM to load the next next opcode
								mem_addr_next <= PC + 12'd2;
								state <= FETCH;
							end
						end
					4'hF: // WAITA
						begin
							if (A == 0) begin
								if (T[8]) begin
									A <= T[7:0];
								end
								T <= 0;
								PC <= PC + 1'b1;
								mem_addr <= PC + 12'd1;
								mem_addr_next <= PC + 12'd2;
								state <= FETCH;
							end else begin
								if (!T[8]) begin
									T <= {1'b1, A};
								end
								A <= A - 1'b1;
								// we don't update PC/mem_addr since we're re-running this opcode
							end
						end
				endcase
			end
		4'hF: // SBIT
			begin
				if (A[s_imm] == b_imm) begin
					// skipping next opcode
					PC <= PC + 12'd2;
					mem_addr <= PC + 12'd2;
					mem_addr_next <= PC + 12'd3;
				end else begin
					// not skipping
					instruct <= instruct_imm;
					PC <= PC + 12'd1;
					mem_addr <= PC + 12'd1;
					mem_addr_next <= PC + 12'd2;
				end
			end
	endcase
end
