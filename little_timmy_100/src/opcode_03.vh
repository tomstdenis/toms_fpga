// case (opcode) begin ...
7'd3: // load commands
begin
    bus_addr <= rv_regs[op_rs1] + op_imm_i;
    bus_wr_en <= 0; // READ
    ldd <= op_rd;
    tag <= LT_FETCH;
    bus_enable <= 1; // issue
    case(op_funct3)
        3'd0: // load byte signed
            begin
                bus_be <= 4'b0001; // 8-bit
                state = LT_WAIT_LOAD_RD_SIGN_BYTE;
            end
        3'd1: // load half
            begin
                bus_be <= 4'b0011; // 32-bit
                state = LT_WAIT_LOAD_RD_SIGN_HALF;
                tag <= LT_FETCH;
            end
        3'd2: // load word
            begin
                bus_be <= 4'b1111; // 32-bit
                state = LT_WAIT_LOAD_RD;
            end
        3'd4: // load byte (U)
            begin
                bus_be <= 4'b0001; // 8-bit
                state = LT_WAIT_LOAD_RD;
            end
        3'd5: // load half (U)
            begin
                bus_be <= 4'b0011; // 32-bit
                state = LT_WAIT_LOAD_RD;
            end
    endcase
end
