/* Really simple 9-bit DP16KD simulation model */

`timescale 1ns/1ps
`default_nettype none
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off MULTIDRIVEN */
module DP16KD #(
    parameter DATA_WIDTH_A = 9,
    parameter DATA_WIDTH_B = 9,
    parameter WRITEMODE_A = "NORMAL",
    parameter WRITEMODE_B = "NORMAL",
    parameter REGMODE_A = "NOREG",
    parameter REGMODE_B = "NOREG",
    parameter GSR = "DISABLED"
)(
    input wire CLKA, CEA, OCEA, WEA, RSTA,
    input wire ADA13, ADA12, ADA11, ADA10, ADA9, ADA8, ADA7, ADA6, ADA5, ADA4, ADA3, ADA2, ADA1, ADA0,
    input wire DIA8, DIA7, DIA6, DIA5, DIA4, DIA3, DIA2, DIA1, DIA0,
    output reg DOA8, DOA7, DOA6, DOA5, DOA4, DOA3, DOA2, DOA1, DOA0,

    input wire CLKB, CEB, OCEB, WEB, RSTB,
    input wire ADB13, ADB12, ADB11, ADB10, ADB9, ADB8, ADB7, ADB6, ADB5, ADB4, ADB3, ADB2, ADB1, ADB0,
    input wire DIB8, DIB7, DIB6, DIB5, DIB4, DIB3, DIB2, DIB1, DIB0,
    output reg DOB8, DOB7, DOB6, DOB5, DOB4, DOB3, DOB2, DOB1, DOB0
);

    // Internal memory array: 2048 words of 9 bits [cite: 1, 5]
    reg [8:0] mem [0:2047];

    // Combine address bits as mapped in the source [cite: 5, 7]
    wire [10:0] addr_a_int = {ADA13, ADA12, ADA11, ADA10, ADA9, ADA8, ADA7, ADA6, ADA5, ADA4, ADA3};
    wire [10:0] addr_b_int = {ADB13, ADB12, ADB11, ADB10, ADB9, ADB8, ADB7, ADB6, ADB5, ADB4, ADB3};

    // Data concatenation
    wire [8:0] din_a_int = {DIA8, DIA7, DIA6, DIA5, DIA4, DIA3, DIA2, DIA1, DIA0};
    wire [8:0] din_b_int = {DIB8, DIB7, DIB6, DIB5, DIB4, DIB3, DIB2, DIB1, DIB0};

    // Output Registers for REGMODE
    reg [8:0] pipe_a, pipe_b, reg_a, reg_b;

    // --- Port A Logic ---
    always @(posedge CLKA) begin
        if (CEA) begin
            if (WEA) begin
                mem[addr_a_int] <= din_a_int;
                // Handle WRITEMODE_A
                if (WRITEMODE_A == "WRITETHROUGH")
                    pipe_a <= din_a_int;
                else if (WRITEMODE_A == "READBEFOREWRITE")
                    pipe_a <= mem[addr_a_int];
            end else begin
                pipe_a <= mem[addr_a_int];
            end
			reg_a <= pipe_a;
        end
    end

    // --- Port B Logic ---
    always @(posedge CLKB) begin
        if (CEB) begin
            if (WEB) begin
                mem[addr_b_int] <= din_b_int;
                if (WRITEMODE_B == "WRITETHROUGH")
                    pipe_b <= din_b_int;
                else if (WRITEMODE_B == "READBEFOREWRITE")
                    pipe_b <= mem[addr_b_int];
            end else begin
                pipe_b <= mem[addr_b_int];
            end
			reg_b <= pipe_b;
        end
    end

    // --- Output Assignments (Handling REGMODE and Reset) ---
    always @(*) begin
        // Port A Output
        {DOA8, DOA7, DOA6, DOA5, DOA4, DOA3, DOA2, DOA1, DOA0} = (REGMODE_A == "REG") ? reg_a : pipe_a;
        // Port B Output
        {DOB8, DOB7, DOB6, DOB5, DOB4, DOB3, DOB2, DOB1, DOB0} = (REGMODE_B == "REG") ? reg_b : pipe_b;
    end
endmodule
/* verilator lint_on WIDTHEXPAND */
/* verilator lint_on MULTIDRIVEN */
