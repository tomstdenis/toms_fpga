`ifndef BOTTOM
// case (opcode) begin ...
7'h13: // OP-IMM commands
begin
    state <= LT_FETCH;
    reg_op_rd <= op_rd;
    case(op_funct3)
        3'd0: // ADDI
            res <= reg_rs1 + reg_op_imm_i;
        3'd1: // SLLI
            res <= reg_rs1 << (reg_op_imm_i & 5'h1F);
        3'd2: // SLTI
            res <= ($signed(reg_rs1) < $signed(reg_op_imm_i)) ? 32'b1 : 32'b0;
        3'd3: // SLTIU
            res <= (reg_rs1 < reg_op_imm_i) ? 32'b1 : 32'b0;
        3'd4: // XORI
            res <= reg_rs1 ^ reg_op_imm_i;
        3'd5: // SRLI/SRAI
            begin
                if (op_funct7 & 7'h20) begin
                    res <= $signed(reg_rs1) >>> reg_op_imm_i[4:0];
                end else begin
                    res <= reg_rs1 >> reg_op_imm_i[4:0];
                end
            end
        3'd6: // ORI
            res <= reg_rs1 | reg_op_imm_i;
        3'd7: // ANDI
            res <= reg_rs1 & reg_op_imm_i;
    endcase
end
`endif