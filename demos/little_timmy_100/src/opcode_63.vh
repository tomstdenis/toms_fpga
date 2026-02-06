`ifndef BOTTOM
// code that goes in the LT_EXECUTE cycle
7'h63: // Branch Instructions
begin
    reg_op_rd <= 0;
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

`else

// code that goes in the main state loop (used for multi cycle instructions)
LT_EXECUTE_BRANCH_2: // 2nd cycle of branch instructions [63]
    begin
        if (res[0]) begin
            // Branch Taken: Adjust from the ALREADY incremented PC
            rv_PC <= (rv_PC - 32'd4) + reg_op_imm_b;
        end 
        // If not taken, rv_PC is already at PC+4, so we just go fetch
        state  <= LT_FETCH; 
    end

`endif