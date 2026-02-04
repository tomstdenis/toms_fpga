7'h63: // Branch Instructions
begin
    case(op_funct3)
        3'd0: res = (rv_regs[op_rs1] == rv_regs[op_rs2]) ? 1 : 0; // BEQ
        3'd1: res = (rv_regs[op_rs1] != rv_regs[op_rs2]) ? 1 : 0; // BNE
        3'd4: res = ($signed(rv_regs[op_rs1]) < $signed(rv_regs[op_rs2])) ? 1 : 0; // BLT
        3'd5: res = ($signed(rv_regs[op_rs1]) >= $signed(rv_regs[op_rs2])) ? 1 : 0; // BGE
        3'd6: res = (rv_regs[op_rs1] < rv_regs[op_rs2]) ? 1 : 0; // BLTU
        3'd7: res = (rv_regs[op_rs1] >= rv_regs[op_rs2]) ? 1 : 0; // BGEU
        default: res = 0;
    endcase

    if (res[0]) begin
        // Branch Taken: Adjust from the ALREADY incremented PC
        rv_PC <= (rv_PC - 32'd4) + op_imm_b;
    end
    // If not taken, rv_PC is already at PC+4, so we just go fetch
    state <= LT_FETCH; 
end