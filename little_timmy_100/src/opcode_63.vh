7'h63: // Branch Instructions
begin

    case(op_funct3)
        3'd0: res <= (reg_rs1 == reg_rs2) ? 1 : 0; // BEQ
        3'd1: res <= (reg_rs1 != reg_rs2) ? 1 : 0; // BNE
        3'd4: res <= ($signed(reg_rs1) < $signed(reg_rs2)) ? 1 : 0; // BLT
        3'd5: res <= ($signed(reg_rs1) >= $signed(reg_rs2)) ? 1 : 0; // BGE
        3'd6: res <= (reg_rs1 < reg_rs2) ? 1 : 0; // BLTU
        3'd7: res <= (reg_rs1 >= reg_rs2) ? 1 : 0; // BGEU
        default: res <= 0;
    endcase
    state <= LT_EXECUTE_BRANCH_2;
end
