7'h37: // LUI
    begin
        res <= instr_reg & 32'hFFFFF000;
        state <= LT_RETIRE;
    end
7'h17: // AUIPC
    begin
        res <= rv_PC - 4 + (instr_reg & 32'hFFFFF000);
        state <= LT_RETIRE;
    end
7'h67: // JALR
    begin
        res <= rv_PC; // Store return address
        // Target is (rs1 + imm_i), then force bit 0 to 0 per spec
        rv_PC <= (rv_regs[op_rs1] + op_imm_i) & ~32'h1; 
        state <= LT_RETIRE;
    end
7'h6F: // JAL
    begin
        res <= rv_PC; // Store the return address (already PC+4)
        rv_PC <= (rv_PC - 32'd4) + op_imm_j; // Jump relative to current instruction
        state <= LT_RETIRE;
    end
