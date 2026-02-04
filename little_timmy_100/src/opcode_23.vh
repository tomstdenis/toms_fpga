// case (opcode) begin ...
7'h23: // Store opcodes
begin
    bus_addr <= reg_rs1 + op_imm_s;
    bus_i_data <= reg_rs2;
    bus_wr_en <= 1;
    bus_enable <= 1;
    state <= LT_WAIT_FOR_STORE;
    tag <= LT_FETCH;
    case(op_funct3)
        3'd0: // store byte
            bus_be <= 4'b0001;
        3'd1: // store half
            bus_be <= 4'b0011;
        3'd2: // store word
            bus_be <= 4'b1111;
    endcase
end