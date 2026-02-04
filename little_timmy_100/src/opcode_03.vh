`ifndef BOTTOM
// case (opcode) begin ...
7'd3: // load commands
begin
    bus_addr <= reg_rs1 + reg_op_imm_i;
    bus_wr_en <= 0; // READ
    tag <= LT_FETCH;
    case(op_funct3)
        3'd0: // load byte signed
            begin
                bus_be <= 4'b0001; // 8-bit
                bus_enable <= 1; // issue
                state <= LT_WAIT_LOAD_RD_SIGN_BYTE;
            end
        3'd1: // load half
            begin
                bus_be <= 4'b0011; // 32-bit
                bus_enable <= 1; // issue
                state <= LT_WAIT_LOAD_RD_SIGN_HALF;
            end
        3'd2: // load word
            begin
                bus_be <= 4'b1111; // 32-bit
                bus_enable <= 1; // issue
                state <= LT_WAIT_LOAD_RD;
            end
        3'd4: // load byte (U)
            begin
                bus_be <= 4'b0001; // 8-bit
                bus_enable <= 1; // issue
                state <= LT_WAIT_LOAD_RD;
            end
        3'd5: // load half (U)
            begin
                bus_be <= 4'b0011; // 32-bit
                bus_enable <= 1; // issue
                state <= LT_WAIT_LOAD_RD;
            end
        default: // invalid load just fetch the next instruction
            begin
                state <= LT_FETCH;
            end

    endcase
end
`endif