// Monolith FSM version of Toy ISA
// based on core #0, this starts a new instruction fetch during execute
// mostly this is just to test my scriptware but also see if the cycle counting is reflected
// accurately

`default_nettype none
`timescale 1ns/1ps

module toy_isa(
    input wire clk,
    input wire rst_n,

    output reg is_halted,

    // port A
    output reg [7:0] bus_addr_a,
    output reg [7:0] bus_data_in_a,
    input wire [7:0] bus_data_out_a,
    output reg bus_wr_en_a,
    output reg bus_valid_a,
    input wire bus_ready_a,

    // port B
    output reg [7:0] bus_addr_b,
    output reg [7:0] bus_data_in_b,
    input wire [7:0] bus_data_out_b,
    output reg bus_wr_en_b,
    output reg bus_valid_b,
    input wire bus_ready_b
);
    // ISA
    reg [7:0] PC;
    reg [7:0] R[3:0];
    reg       ZF;

    // FSM
    localparam
        FSM_FETCH = 0,
        FSM_EXECUTE = 1,
        FSM_RETIRE  = 2;
    reg [1:0]  fsm_state;
    reg [7:0]  opcode;
    wire [2:0] insn;
    wire [1:0] rs;
    wire [1:0] rd;
    wire [7:0] simm5;
    wire [7:0] uimm5;

    assign insn  = opcode[7:5];
    assign rs    = opcode[3:2];
    assign rd    = opcode[1:0];
    assign simm5 = {opcode[4], opcode[4], opcode[4], opcode[4:0]};
    assign uimm5 = {3'b0, opcode[4:0]};

    always @(posedge clk) begin
        if (!rst_n) begin
            PC   <= 32;
            R[0] <= 0;
            R[1] <= 0;
            R[2] <= 0;
            R[3] <= 0;
            ZF   <= 0;

            fsm_state        <= FSM_FETCH;
            is_halted        <= 0;
            bus_addr_a       <= 0;
            bus_data_in_a    <= 0;
            bus_wr_en_a      <= 0;
            bus_valid_a      <= 0;
            bus_addr_b       <= 0;
            bus_data_in_b    <= 0;
            bus_wr_en_b      <= 0;
            bus_valid_b      <= 0;
        end else begin
            case (fsm_state)
                FSM_FETCH, FSM_RETIRE:
                    begin
                        if (fsm_state == FSM_RETIRE) begin
                            ZF        <= R[rs] == 0 ? 1 : 0;
                        end
                        if (!bus_valid_a && !is_halted) begin
                            // initiate read of PC
                            bus_addr_a  <= PC;
                            bus_wr_en_a <= 0;
                            bus_valid_a <= 1;
                        end else if (bus_valid_a && bus_ready_a) begin
                            PC          <= PC + 1;
                            bus_valid_a <= 0;
                            opcode      <= bus_data_out_a;
                            fsm_state   <= FSM_EXECUTE;
                        end
                    end
                FSM_EXECUTE:
                    begin
                        bus_valid_a <= 1;                      
                        bus_addr_a  <= PC;
                        if (!bus_valid_b) begin
                            fsm_state  <= FSM_FETCH;
                            bus_addr_b <= R[rd];
                            case (insn)
                                0: // add
                                    begin
                                        R[rs]         <= R[rs] + R[rd];
                                        fsm_state     <= FSM_RETIRE;
                                    end
                                1: // sub
                                    begin
                                        R[rs]         <= R[rs] - R[rd];
                                        fsm_state     <= FSM_RETIRE;
                                    end
                                2: // ldi
                                    begin
                                        R[0]          <= uimm5;
                                        ZF            <= uimm5 == 0 ? 1 : 0;
                                    end
                                3: // ld
                                    begin
                                        bus_valid_b   <= 1;
                                        fsm_state     <= fsm_state;
                                    end
                                4: // st
                                    begin
                                        bus_valid_b   <= 1;
                                        bus_data_in_b <= R[rs];
                                        bus_wr_en_b   <= 1;
                                        fsm_state     <= fsm_state;
                                    end
                                5: // jmp
                                    begin
                                        PC            <= PC - 1 + simm5;
                                        bus_addr_a    <= PC - 1 + simm5;
                                    end
                                6: // jz
                                    begin
                                        if (ZF) begin
                                            PC         <= PC - 1 + simm5;
                                            bus_addr_a <= PC - 1 + simm5;
                                        end
                                    end
                                7: // halt
                                    begin
                                        is_halted     <= 1;
                                    end
                            endcase
                        end else if (bus_valid_b && bus_ready_b) begin
                            bus_valid_b <= 0;
                            bus_wr_en_b <= 0;
                            fsm_state   <= FSM_FETCH;
                            case (insn)
                                3: // ld
                                    begin
                                        R[rs]     <= bus_data_out_b;
                                        fsm_state <= FSM_RETIRE;
                                    end
                            endcase
                        end
                    end
            endcase
        end
    end
endmodule