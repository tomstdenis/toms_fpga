module lt100(
    input clk,
    input rst_n,

    input rx_pin,
    output tx_pin,
    output pwm
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

    lt100_bus ltb(
        .clk(clk), .rst_n(rst_n), .enable(bus_enable), .wr_en(bus_wr_en),
        .addr(bus_addr), .i_data(bus_i_data), .be(bus_be), .ready(bus_ready),
        .o_data(bus_o_data), .irq(bus_irq), .bus_err(bus_err),
        .rx_pin(rx_pin), .tx_pin(tx_pin), .pwm(pwm));

    reg [31:0] rv_regs[31:0];
    reg [31:0] rv_PC;

    reg [31:0] instr_reg;
    reg [7:0] state;
    reg [7:0] tag;
    reg [4:0] ldd;
    reg [31:0] res;
    
    localparam
        LT_WAIT_FOR_READY=0,
        LT_WAIT_FOR_FETCH=1,
        LT_FETCH=2,
        LT_EXECUTE=3,
        LT_WAIT_LOAD_RD_SIGN_BYTE=4,
        LT_WAIT_LOAD_RD_SIGN_HALF=5,
        LT_WAIT_LOAD_RD=6,
        LT_RETIRE=7,
        LT_WAIT_FOR_STORE=8;

    // Slicing the RISC-V Instruction (Standard 32-bit)
    wire [6:0] op_opcode = instr_reg[6:0];
    wire [4:0] op_rd     = instr_reg[11:7];
    wire [2:0] op_funct3 = instr_reg[14:12];
    wire [4:0] op_rs1    = instr_reg[19:15];
    wire [4:0] op_rs2    = instr_reg[24:20];
    wire [6:0] op_funct7 = instr_reg[31:25];

    // Examples of Immediate Slicing (The "unscrambling")
    wire [31:0] op_imm_i = {{20{instr_reg[31]}}, instr_reg[31:20]}; // I-type
    wire [31:0] op_imm_s = {{20{instr_reg[31]}}, instr_reg[31:25], instr_reg[11:7]}; // S-type        
    // B-type immediate (Branch)
    wire [31:0] op_imm_b = {{20{instr_reg[31]}}, instr_reg[7], instr_reg[30:25], instr_reg[11:8], 1'b0};
    // J-type immediate (JAL)
    wire [31:0] op_imm_j = {{12{instr_reg[31]}}, instr_reg[19:12], instr_reg[20], instr_reg[30:21], 1'b0};

    always @(posedge clk) begin
        if (!rst_n) begin
            rv_regs[0] <= 0;    // at least r0 should be zero'ed
            rv_PC <= 0;
            instr_reg <= 0;
            state <= LT_FETCH;
        end else begin
            case(state)
                LT_WAIT_FOR_STORE:
                    begin
                        if (bus_ready) begin
                            bus_enable <= 0;
                            state <= tag;
                        end
                    end
                LT_WAIT_LOAD_RD:                        // wait on a 32-bit (or unsigned) load to a register
                    begin
                        if (bus_ready) begin
                            bus_enable <= 0;
                            rv_regs[ldd] <= bus_o_data;
                            state <= tag;
                        end
                    end
                LT_WAIT_LOAD_RD_SIGN_BYTE:              // wait on a signed byte extension to a register
                    begin
                        if (bus_ready) begin
                            bus_enable <= 0;
                            rv_regs[ldd] <= {{24{bus_o_data[7]}}, bus_o_data[7:0]};
                            state <= tag;
                        end
                    end
                LT_WAIT_LOAD_RD_SIGN_HALF:              // wait on a signed half extension to a register
                    begin
                        if (bus_ready) begin
                            bus_enable <= 0;
                            rv_regs[ldd] <= {{16{bus_o_data[7]}}, bus_o_data[15:0]};
                            state <= tag;
                        end
                    end
                LT_WAIT_FOR_FETCH:                      // wait for 32-bit read into instruc_reg
                    begin
                        if (bus_ready) begin
                            bus_enable <= 0;
                            instr_reg <= bus_o_data;
                            state <= tag;
                            rv_PC <= rv_PC + 32'd4;     // advance PC since there are multiple return paths to LT_FETCH make
                                                        // sure to account for this in branch opcodes
                        end
                    end
                LT_FETCH:                               // issue fetch of next opcode 
                    begin
                        bus_wr_en <= 0;         // READ
                        bus_be <= 4'b1111;      // 32-bit
                        bus_addr <= rv_PC;      // from PC
                        bus_enable <= 1;        // issue read
                        tag = LT_EXECUTE;
                        state <= LT_WAIT_FOR_FETCH;
                    end
                LT_EXECUTE:                             // execute instruction
                    begin
                        case(op_opcode)
`include "opcode_03.vh"
`include "opcode_13.vh"
`include "opcode_23.vh"
`include "opcode_63.vh"
`include "opcode_misc.vh"
                        endcase
                    end
                LT_RETIRE:
                    begin
                        rv_regs[op_rd] <= res;
                        state <= LT_FETCH;
                    end
            endcase
         end
    end
endmodule