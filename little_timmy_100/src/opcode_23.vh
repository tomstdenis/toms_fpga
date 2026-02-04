`ifndef BOTTOM
// case (opcode) begin ...
7'h23: // Store opcodes
begin
    bus_addr <= reg_rs1 + reg_op_imm_s;
    bus_i_data <= reg_rs2;
    bus_wr_en <= 1;
    reg_op_rd <= 0;
    case(op_funct3)
        3'd0: // store byte
        begin
            bus_enable <= 1;
            bus_be <= 4'b0001;
            state <= LT_WAIT_FOR_STORE;
            tag <= LT_FETCH;
        end
        3'd1: // store half
        begin
            bus_enable <= 1;
            bus_be <= 4'b0011;
            state <= LT_WAIT_FOR_STORE;
            tag <= LT_FETCH;
        end
        3'd2: // store word
        begin
            bus_enable <= 1;
            bus_be <= 4'b1111;
            state <= LT_WAIT_FOR_STORE;
            tag <= LT_FETCH;
        end
        default:
            state <= LT_FETCH; // fetch next instruction on invalid opcode
    endcase
end
`else   
`endif