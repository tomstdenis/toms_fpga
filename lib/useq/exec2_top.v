// This is the top of the EXECUTE2 case statement in the FSM
begin
	case(instruct[7:4])
		4'h0: // ADD r, s
			begin
				R[e2_r] <= R[e2_r] + R[e2_s];
			end
		4'h1: // SUB r, s
			begin
				R[e2_r] <= R[e2_r] - R[e2_s];
			end
		4'h2: // EOR r, s
			begin
				R[e2_r] <= R[e2_r] ^ R[e2_s];
			end
		4'h3: // AND r, s
			begin
				R[e2_r] <= R[e2_r] & R[e2_s];
			end
		4'h4: // OR r, s
			begin
				R[e2_r] <= R[e2_r] | R[e2_s];
			end
		4'h5: // MOV r, s
			begin
				R[e2_r] <= R[e2_s];
			end
		4'h6:
			case(e2_r[1:0])
				2'd0: // NEG
					begin
						R[e2_s] <= -R[e2_s];
					end
				2'd1: // CLR
					begin
						R[e2_s] <= 0;
					end
				2'd2: // LDI
					begin
						state <= FETCH;
						R[e2_s] <= mem_data;			// this was prefetched 
						PC <= PC + 8'd2;				// skip over immediate
						mem_addr <= PC + 8'd2;
					end
				2'd3: // XCH
					begin
						A <= R[e2_s];
						R[e2_s] <= A;
					end
			endcase
		4'h7:
			case(e2_r[1:0])
				2'd0: // LDIND1 r
					begin
						A <= R[4'd4 + e2_s];
					end
				2'd1: // LDIND2
					begin
						A <= R[4'd8 + e2_s];
					end
				2'd2: // STIND1
					begin
						R[4'd4 + e2_s] <= A;
					end
				2'd3: // STIND2
					begin
						R[4'd8 + e2_s] <= A;
					end
			endcase
		4'h8: // SIGT
			begin
				if (R[e2_r] > R[e2_s]) begin
					PC <= PC + 8'd2;
					mem_addr <= PC + 8'd2;
				end else begin
					PC <= PC + 8'd1;
					mem_addr <= PC + 8'd1;
				end
				state <= FETCH;
			end
		4'h9: // SIEQ
			begin
				if (R[e2_r] == R[e2_s]) begin
					PC <= PC + 8'd2;
					mem_addr <= PC + 8'd2;
				end else begin
					PC <= PC + 8'd1;
					mem_addr <= PC + 8'd1;
				end
				state <= FETCH;
			end
		4'hA: // SILT
			begin
				if (R[e2_r] < R[e2_s]) begin
					PC <= PC + 8'd2;
					mem_addr <= PC + 8'd2;
				end else begin
					PC <= PC + 8'd1;
					mem_addr <= PC + 8'd1;
				end
				state <= FETCH;
			end
		4'hB: // shifts
			case(e2_r[1:0])
				2'h0: // ASR
					begin
						R[e2_s] <= {e2_s_wire[7], e2_s_wire[7:1]};
					end
				2'h1: // LSR
					begin
						R[e2_s] <= R[e2_s] >> 1;
					end
				2'h2: // ADDA
					begin
						R[e2_s] <= R[e2_s] + A;
					end
				2'h3: // SUBA
					begin
						R[e2_s] <= R[e2_s] - A;
					end
			endcase
		4'hC: // FIFO
			case(e2_r[1:0])
				2'h0: // RFIFO
					begin
						if (R[15] > 0) begin
							R[e2_s] <= FIFO[fifo_rptr];
							fifo_rptr <= fifo_rptr + 1'b1;
							R[15] <= R[15] - 1'b1;
						end else begin
							R[e2_s] <= 0;
						end
					end
				2'h1: // WFIFO
					if (R[15] != FIFO_DEPTH) begin
						FIFO[fifo_wptr] <= R[e2_s];
						fifo_wptr <= fifo_wptr + 1'b1;
						R[15] <= R[15] + 1'b1;
					end
				2'h2: // QFIFO
					begin
						R[e2_s] <= R[15];
					end
				2'h3: // WAITF
					begin
						if (R[e2_s] <= R[15]) begin
							PC <= PC + 1'b1;			// FIFO has enough contents advance to the next
							mem_addr <= PC + 8'd2;		// we're chaining so we need to tell the ROM to load the next next opcode
							instruct <= mem_data;		// we can technically just advance since we loaded the opcode for PC+1 already
						end
					end
			endcase
		4'hD: // LOG A
			case(e2_r[1:0])
				2'h0: // ANDA
					begin
						R[e2_s] <= R[e2_s] & A;
					end
				2'h1: // ORA
					begin
						R[e2_s] <= R[e2_s] | A;
					end
				2'h2: // EORA
					begin
						R[e2_s] <= R[e2_s] ^ A;
					end
				2'h3: // LDA
					begin
						R[e2_s] <=  A;
					end
			endcase
		4'hE: // JNZ/JZ/DEC/IN
			case(e2_r[1:0])
				2'h0: // JNZ
					begin
						if (R[e2_s] != 0) begin
							PC <= PC - mem_data - 8'd1;
							mem_addr <= PC - mem_data - 8'd1;
						end else begin
							PC <= PC + 1'b1;
							mem_addr <= PC + 1'b1;
						end
						state <= FETCH;
					end
				2'h1: // JZ
					begin
						if (R[e2_s] == 0) begin
							PC <= PC - mem_data - 8'd1;
							mem_addr <= PC - mem_data - 8'd1;
						end else begin
							PC <= PC + 1'b1;
							mem_addr <= PC + 1'b1;
						end
						state <= FETCH;
					end
				2'h2: // DEC r
					begin
						R[e2_s] <= R[e2_s] - 1'b1;
					end
				2'h3: // INC r
					begin
						R[e2_s] <= R[e2_s] + 1'b1;
					end
			endcase
		4'hF: // JMP/CALL/RET/EXEC1/etc...
			case(e2_r[1:0]) // bits 3:2 of opcode
				2'h0: // JMP,CALL,RET
					case (e2_s[1:0]) // bits 1:0 of opcode
						2'h0: // JMP
							begin
								PC <= mem_data;
								mem_addr <= mem_data;
								state <= FETCH;
							end
						2'h1: // CALL
							begin
								LR <= PC + 8'd2;
								PC <= mem_data;
								mem_addr <= mem_data;
								state <= FETCH;
							end
						2'h2: // RET
							begin
								PC <= LR;
								mem_addr <= LR;
								state <= FETCH;
							end
						2'h3: // RTI
							begin
								if (ENABLE_IRQ == 1) begin
									int_enable <= 1;	// restore interrupt enabled
									PC <= ILR;			// restore PC
									A <= tA;			// restore A
									R[0] <= tR[0];		// restore R[0] and R[1]
									R[1] <= tR[1];
									mem_addr <= ILR;	// fetch instruction we interrupted
									state <= FETCH;		// we need a FETCH cycle to load instruct
									mode <= prevmode;	// restore previous EXEC mode
								end else begin
									PC <= PC + 1'b1;
									mem_addr <= PC + 1'b1;
									state <= FETCH;
								end
							end
						default: begin end
					endcase
				2'h1: // IN/OUT/EXEC1/WAITA (bits 3:2 of opcode)
					begin
						case(e2_s[1:0])
							2'd0: // IN
								begin
									A <= l_i_port;
								end
							2'd1: // OUT
								begin
									o_port <= A;
									o_port_pulse <= o_port_pulse ^ 1'b1;
								end
							2'd2: // EXEC1
								begin
									if (ENABLE_EXEC1 == 1) begin
										mode <= 0;
										state <= EXECUTE;
										PC <= PC + 1'b1;
										mem_addr <= PC + 8'd2;
										instruct <= mem_data;
									end
								end
							2'd3: // WAITA
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
							default: begin end
						endcase
					end
				2'h2: // SEI
					begin
						if (ENABLE_IRQ == 1) begin
							int_mask <= R[e2_s];
							int_enable <= (R[e2_s] == 0) ? 1'b0 : 1'b1;
							irqmode <= 1; // ISR will be in EXEC2 mode
						end
					end
				2'h3: // SIA
					begin
						if (ENABLE_IRQ == 1) begin
							isr_vect <= R[e2_s];
						end
					end
				default: begin end
			endcase
	endcase
end
