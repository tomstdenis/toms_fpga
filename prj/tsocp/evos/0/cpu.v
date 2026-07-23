// Monolith FSM version of Toy ISA
// this is meant to be the base "gold" verilog version to complement
// the sim.py simulator

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
    reg [7:0] reg_rs;
    reg [7:0] reg_rd;
    reg       ZF;
    reg       reg_wr_en;
    reg [7:0] aluout;

    // FSM
    localparam
        FSM_FETCH    = 0,
        FSM_OPERANDS = 1,
        FSM_EXECUTE  = 2,
        FSM_RETIRE   = 3;

    reg [1:0]  fsm_state;
    reg [7:0]  opcode;
    wire [3:0] insn;
    wire [1:0] rs;
    wire [1:0] rd;

    assign insn  = opcode[7:4];
    assign rs    = opcode[3:2];
    assign rd    = opcode[1:0];

    always @(posedge clk) begin
        if (!rst_n) begin
            PC   <= 0;
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
            aluout           <= 0;
            reg_rd           <= 0;
            reg_rs           <= 0;
            reg_wr_en        <= 0;
        end else begin
            case (fsm_state)
                FSM_FETCH:
                    begin
                        if (!bus_valid_a && !is_halted) begin
                            // initiate read of PC
                            bus_addr_a  <= PC;
                            PC          <= PC + 1;
                            bus_wr_en_a <= 0;
                            bus_valid_a <= 1;
                        end else if (bus_valid_a && bus_ready_a) begin
                            bus_valid_a <= 0;
                            opcode      <= bus_data_out_a;
                            fsm_state   <= FSM_OPERANDS;
                        end
                    end
                FSM_OPERANDS:
                    begin
                        reg_rs    <= R[rs];
                        reg_rd    <= R[rd];
                        reg_wr_en <= 0;
                        fsm_state <= FSM_EXECUTE;
                    end
                FSM_EXECUTE:
                    begin
                        if (!bus_valid_b) begin
                            fsm_state  <= FSM_FETCH;
                            case (insn)
                                0: // add
                                    begin
                                        reg_wr_en     <= 1;
                                        aluout        <= reg_rs + reg_rd;
                                        fsm_state     <= FSM_RETIRE;
                                    end
                                1: // sub
                                    begin
                                        reg_wr_en     <= 1;
                                        aluout        <= reg_rs - reg_rd;
                                        fsm_state     <= FSM_RETIRE;
                                    end
                                2: // xor
                                    begin
                                        reg_wr_en     <= 1;
                                        aluout        <= reg_rs ^ reg_rd;
                                        fsm_state     <= FSM_RETIRE;
                                    end
                                3: // or
                                    begin
                                        reg_wr_en     <= 1;
                                        aluout        <= reg_rs | reg_rd;
                                        fsm_state     <= FSM_RETIRE;
                                    end
                                4: // and
                                    begin
                                        reg_wr_en     <= 1;
                                        aluout        <= reg_rs & reg_rd;
                                        fsm_state     <= FSM_RETIRE;
                                    end
                                5: // ldi
                                    begin
                                        fsm_state     <= fsm_state;
                                        bus_valid_b   <= 1;
                                        bus_addr_b    <= PC;
                                        PC            <= PC + 1;
                                    end
                                6: // ld
                                    begin
                                        bus_valid_b   <= 1;
                                        bus_addr_b    <= reg_rd;
                                        fsm_state     <= fsm_state;
                                    end
                                7: // st
                                    begin
                                        bus_valid_b   <= 1;
                                        bus_data_in_b <= reg_rs;
                                        bus_addr_b    <= reg_rd;
                                        bus_wr_en_b   <= 1;
                                        fsm_state     <= fsm_state;
                                    end
                                8: // jmps
                                    begin
										fsm_state     <= fsm_state;
										bus_valid_b   <= 1;
										bus_addr_b    <= PC;
										case (rd)
											0: // JMP
												begin
												end
											1: // JZ
												begin
													if (ZF) begin
													end else begin
														fsm_state     <= FSM_FETCH;
														bus_valid_b   <= 0;
														PC            <= PC + 1;
													end
												end
											2: // JNZ
												begin
													if (!ZF) begin
													end else begin
														fsm_state     <= FSM_FETCH;
														bus_valid_b   <= 0;
														PC            <= PC + 1;
													end
												end
											3: // JALR
												begin
													R[3]              <= PC + 1;
												end
										endcase
                                    end
                                9: // inc/dec/shr
                                    begin
										fsm_state <= FSM_RETIRE;
										reg_wr_en <= 1;
										case (rd)
											0: // INC
												aluout <= reg_rs + 1;
											1: // DEC
												aluout <= reg_rs - 1;
											2: // SHR
												aluout <= {1'b0, reg_rs[7:1]};
										endcase
                                    end
                                10: // XXXX
                                    begin
                                    end
                                11: // ret
                                    begin
                                        case (rd)
                                            0:
                                                begin
                                                    PC        <= R[3];
                                                end
                                            1: // not
                                                begin
                                                    aluout    <= ~reg_rs;
                                                    reg_wr_en <= 1;
                                                    fsm_state <= FSM_RETIRE;
                                                end
                                            2: // neg
                                                begin
                                                    aluout    <= -reg_rs;
                                                    reg_wr_en <= 1;
                                                    fsm_state <= FSM_RETIRE;
                                                end
                                            3: // swap
                                                begin
                                                    aluout    <= {reg_rs[3:0], reg_rs[7:4]};
                                                    reg_wr_en <= 1;
                                                    fsm_state <= FSM_RETIRE;
                                                end
                                        endcase
                                    end
                                12: // SILT
                                    begin
                                        fsm_state <= FSM_RETIRE;
										aluout    <= (reg_rs < reg_rd) ? 0 : 1;
                                    end
                                13: // SIEQ
                                    begin
                                        fsm_state <= FSM_RETIRE;
										aluout    <= (reg_rs == reg_rd) ? 0 : 1;
                                    end
                                14: // SIGT
                                    begin
                                        fsm_state <= FSM_RETIRE;
										aluout    <= (reg_rs > reg_rd) ? 0 : 1;
                                    end
                                15: // halt
                                    begin
                                        case (rd)
                                            0:
                                                begin
                                                    is_halted     <= 1;
                                                end
                                            1: // MSB
                                                begin
                                                    aluout    <= {7'b0, reg_rs[7]};
                                                    fsm_state <= FSM_RETIRE;
                                                end
                                            2: // LSB
                                                begin
                                                    aluout    <= {7'b0, reg_rs[0]};
                                                    fsm_state <= FSM_RETIRE;
                                                end
                                        endcase
                                    end
                            endcase
                        end else if (bus_valid_b && bus_ready_b) begin
                            bus_valid_b <= 0;
                            bus_wr_en_b <= 0;
                            fsm_state   <= FSM_FETCH;
                            case (insn)
                                5: // ldi
                                    begin
                                        reg_wr_en <= 1;
                                        fsm_state <= FSM_RETIRE;
                                        case (rd)
                                            0: aluout <= bus_data_out_b;
                                            1: aluout <= reg_rs + bus_data_out_b;
                                            2: aluout <= reg_rs - bus_data_out_b;
                                            3: aluout <= reg_rs & bus_data_out_b;
                                        endcase
                                    end
                                6: // ld
                                    begin
                                        reg_wr_en <= 1;
                                        aluout    <= bus_data_out_b;
                                        fsm_state <= FSM_RETIRE;
                                    end
                                8: // JMPs
                                    PC <= bus_data_out_b;
                            endcase
                        end
                    end
                FSM_RETIRE:
                    begin
                        if (reg_wr_en) begin
                            R[rs] <= aluout;
                        end
                        ZF        <= aluout == 0 ? 1 : 0;
                        fsm_state <= FSM_FETCH;
                    end
            endcase
        end
    end
endmodule
