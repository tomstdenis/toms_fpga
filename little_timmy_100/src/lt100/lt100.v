module lt100(
    input clk,
    input rst_n,

    input rx_pin,
    output tx_pin,
    output pwm,
    output cpu_pin,
    output led_bus_err
);
    reg bus_enable;
    reg bus_wr_en;
    reg [31:0] bus_addr;
    reg [31:0] bus_i_data;
    reg [3:0] bus_be;
    wire bus_ready;
    wire [31:0] bus_o_data;
    wire bus_irq;
    wire bus_err;
    assign led_bus_err = ~bus_err;

    lt100_bus ltb(
        .clk(clk), .rst_n(rst_n), .enable(bus_enable), .wr_en(bus_wr_en),
        .addr(bus_addr), .i_data(bus_i_data), .be(bus_be), .ready(bus_ready),
        .o_data(bus_o_data), .irq(bus_irq), .bus_err(bus_err),
        .rx_pin(rx_pin), .tx_pin(tx_pin), .pwm(pwm));

    reg [31:0] rv_regs[31:0];
    reg [31:0] rv_PC;

    reg [31:0] instr_reg;
    reg [4:0] state;
    reg [4:0] tag;
    reg [31:0] res;
    
    localparam
        LT_WAIT_FOR_READY=0,
        LT_WAIT_FOR_FETCH=1,
        LT_FETCH=2,
        LT_EXECUTE=3,
        LT_WAIT_LOAD_RD_SIGN_BYTE=4,
        LT_WAIT_LOAD_RD_SIGN_HALF=5,
        LT_WAIT_LOAD_RD=6,
        LT_WAIT_FOR_STORE=8,
        LT_BOOTLOADER=9,
        LT_BOOT_WAIT_RX=10,
        LT_BOOT_READ_CHAR=11,
        LT_BOOT_STORE_CHAR=12,
        LT_BOOT_NEXT_CHAR=13,
        LT_EXECUTE_BRANCH_2=14;

    // Slicing the RISC-V Instruction (Standard 32-bit)
    wire [6:0] op_opcode = instr_reg[6:0];      // the opcode
    wire [2:0] op_funct3 = instr_reg[14:12];    // 3-bit funct3
    wire [6:0] op_funct7 = instr_reg[31:25];    // 7-bit funct7
    wire [4:0] op_rd     = instr_reg[11:7];     // destination register

    reg [15:0] boot_addr;
    reg [31:0] reg_rs1;
    reg [31:0] reg_rs2;
    reg [4:0]  reg_op_rd;
    reg [31:0] reg_op_imm_i;
    reg [31:0] reg_op_imm_s;
    reg [31:0] reg_op_imm_b;
    reg [31:0] reg_op_imm_j;
    reg [6:0]  reg_opcode;
    reg [3:0] boot_step;
    reg fetch_signal;
    assign cpu_pin = fetch_signal;

    always @(posedge clk) begin
        if (!rst_n) begin
            rv_regs[0] <= 0;    // at least r0 should be zero'ed
            rv_PC <= 0;
            instr_reg <= 0;
            state <= LT_BOOTLOADER;
            boot_addr <= 0;
            boot_step <= 0;
            reg_op_rd <= 0;
            res <= 0;
            fetch_signal <= 0;
        end else begin
            case(state)
`include "bootloader_fsm.vh"
                LT_WAIT_FOR_STORE:
                    begin
                        if (bus_ready) begin
                            state <= tag;
                            bus_enable <= 0;
                        end
                    end
                LT_WAIT_LOAD_RD:                        // wait on a 32-bit (or unsigned) load to a register
                    begin
                        if (bus_ready) begin
                            rv_regs[reg_op_rd] <= bus_o_data;
                            bus_enable <= 0;
                            state <= tag;       // we need the idle cycle because we can't deassert just yet and we need bus_enable to be low for at least one cycle for the synchronous peripherals to respond
                        end
                    end
                LT_WAIT_LOAD_RD_SIGN_BYTE:              // wait on a signed byte extension to a register
                    begin
                        if (bus_ready) begin
                            rv_regs[reg_op_rd] <= {{24{bus_o_data[7]}}, bus_o_data[7:0]};
                            bus_enable <= 0;
                            state <= tag;       // we need the idle cycle because we can't deassert just yet and we need bus_enable to be low for at least one cycle for the synchronous peripherals to respond
                        end
                    end
                LT_WAIT_LOAD_RD_SIGN_HALF:              // wait on a signed half extension to a register
                    begin
                        if (bus_ready) begin
                            rv_regs[reg_op_rd] <= {{16{bus_o_data[15]}}, bus_o_data[15:0]};
                            bus_enable <= 0;
                            state <= tag;
                        end
                    end
                LT_WAIT_FOR_FETCH:                      // wait for 32-bit read into instruc_reg
                    begin
                        if (bus_ready) begin
                            // fetch done
                            bus_enable <= 0;
                            instr_reg <= bus_o_data;
                            // preload rs1/rs2 for the opcoming instruction
                            reg_rs1 <= rv_regs[bus_o_data[19:15]];
                            reg_rs2 <= rv_regs[bus_o_data[24:20]];
                            // register various interpretations of the immediate fields
                            reg_op_imm_i <= {{20{bus_o_data[31]}}, bus_o_data[31:20]};                                          // I-type
                            reg_op_imm_s <= {{20{bus_o_data[31]}}, bus_o_data[31:25], bus_o_data[11:7]};                        // S-type
                            reg_op_imm_b <= { bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[7], bus_o_data[30], bus_o_data[29], bus_o_data[28], bus_o_data[27], bus_o_data[26], bus_o_data[25], bus_o_data[11], bus_o_data[10], bus_o_data[9], bus_o_data[8], 1'b0};
                            reg_op_imm_j <= { bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[31], bus_o_data[19], bus_o_data[18], bus_o_data[17], bus_o_data[16], bus_o_data[15], bus_o_data[14], bus_o_data[13], bus_o_data[12], bus_o_data[20], bus_o_data[30], bus_o_data[29], bus_o_data[28], bus_o_data[27], bus_o_data[26], bus_o_data[25], bus_o_data[24], bus_o_data[23], bus_o_data[22], bus_o_data[21], 1'b0};
//                            reg_op_imm_j <= { {12{bus_o_data[31]}}, bus_o_data[19:12], bus_o_data[20], bus_o_data[30:21], 1'b0 };
                            // 32-bit opcodes have the 11 in the bottom 2 bits
                            if (bus_o_data[1:0] == 2'b11) begin
                                rv_PC <= rv_PC + 32'd4;     // advance PC since there are multiple return paths to LT_FETCH make
                                                            // sure to account for this in branch opcodes
                                state <= LT_EXECUTE;
                            end else begin
                                // compact instructions we don't yet support just gracefully skip
                                rv_PC <= rv_PC + 32'd2;
                                state <= LT_FETCH;
                            end
                        end
                    end
                LT_FETCH:                               // issue fetch of next opcode 
                    begin
                        fetch_signal <= ~fetch_signal;
                        bus_wr_en <= 0;         // READ
                        bus_be <= 4'b1111;      // 32-bit
                        bus_addr <= rv_PC;      // from PC
                        bus_enable <= 1;                // assert bus here
                        state <= LT_WAIT_FOR_FETCH;
                        if (reg_op_rd != 0) begin    // retire the previous instruction if destination != 0
                            rv_regs[reg_op_rd] <= res;
                            reg_op_rd <= 0;
                        end
                    end
                LT_EXECUTE:                             // execute instruction
                    begin
                        case(op_opcode)
`include "opcode_03.vh"
`include "opcode_13.vh"
`include "opcode_23.vh"
`include "opcode_63.vh"
`include "opcode_misc.vh"
                        default:
                            state <= LT_FETCH;          // unknown opcode just fetch the next;
                        endcase
                    end
`define BOTTOM
`include "opcode_03.vh"
`include "opcode_13.vh"
`include "opcode_23.vh"
`include "opcode_63.vh"
`include "opcode_misc.vh"
`undef BOTTOM
            default:
                fetch_signal <= 0;
            endcase
         end
    end
endmodule