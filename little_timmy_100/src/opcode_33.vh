7'h33: // ALU opcodes (Register-Register)
begin
    state <= LT_RETIRE;
    if (op_funct7 != 7'h01) begin // non M-extension opcodes
        case (op_funct3)
            3'd0: // add/sub
                begin
                    if (op_funct7 & 7'h20) begin
                        res <= rv_regs[op_rs1] - rv_regs[op_rs2];
                    end else begin
                        res <= rv_regs[op_rs1] + rv_regs[op_rs2];
                    end
                end
            3'd1: // sll (shift left logical)
                res <= rv_regs[op_rs1] << rv_regs[op_rs2][4:0];
            3'd2: // slt (set less than - signed)
                res <= ($signed(rv_regs[op_rs1]) < $signed(rv_regs[op_rs2])) ? 32'h1 : 32'h0;
            3'd3: // sltu (set less than - unsigned)
                res <= (rv_regs[op_rs1] < rv_regs[op_rs2]) ? 32'h1 : 32'h0;
            3'd4: // xor
                res <= rv_regs[op_rs1] ^ rv_regs[op_rs2];
            3'd5: // srl/sra (shift right)
                begin
                    if (op_funct7 & 7'h20) begin
                        // sra (shift right arithmetic)
                        res <= $signed(rv_regs[op_rs1]) >>> rv_regs[op_rs2][4:0];
                    end else begin
                        // srl (shift right logical)
                        res <= rv_regs[op_rs1] >> rv_regs[op_rs2][4:0];
                    end
                end
            3'd6: // or
                res <= rv_regs[op_rs1] | rv_regs[op_rs2];
            3'd7: // and
                res <= rv_regs[op_rs1] & rv_regs[op_rs2];
        endcase
    end
end