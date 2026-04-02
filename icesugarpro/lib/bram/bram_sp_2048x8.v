module bram_sp_2048x8 
#(
	parameter WRITEMODE_A="NORMAL",
	parameter WRITEMODE_B="NORMAL",
	parameter REGMODE_A="NOREG"
)
(
    input clk,
    input [10:0] w_addr,
    input [7:0] w_data,
    input w_en,
    input [10:0] r_addr,
    output [7:0] r_data
);

    // The DP16K has 14-bit address buses (AD). 
    // For 2048 depth (11-bit), the mapping usually shifts 
    // based on the width. In 9-bit mode, AD[2:0] are ignored 
    // or used for sub-byte masking. We map our 11 bits to AD[13:3].

    DP16KD #(
        .DATA_WIDTH_A(9), 
        .DATA_WIDTH_B(9),
        .WRITEMODE_A(WRITEMODE_A),
        .WRITEMODE_B(WRITEMODE_B),
        .REGMODE_A(REGMODE_A), // Use "REG" for a registered output (better timing)
        .GSR("DISABLED")
    ) mem_inst (
        // Port A: Read
        .CLKA(clk),
        .CEA(1'b1),
        .OCEA(1'b1),
        .RSTA(1'b0),
        .ADA13(r_addr[10]), .ADA12(r_addr[9]), .ADA11(r_addr[8]), 
        .ADA10(r_addr[7]),  .ADA9(r_addr[6]),   .ADA8(r_addr[5]), 
        .ADA7(r_addr[4]),   .ADA6(r_addr[3]),   .ADA5(r_addr[2]), 
        .ADA4(r_addr[1]),   .ADA3(r_addr[0]),
        .ADA2(1'b0), .ADA1(1'b0), .ADA0(1'b0),
        .DOA8(), // Ignored 9th bit
        .DOA7(r_data[7]), .DOA6(r_data[6]), .DOA5(r_data[5]), .DOA4(r_data[4]),
        .DOA3(r_data[3]), .DOA2(r_data[2]), .DOA1(r_data[1]), .DOA0(r_data[0]),

        // Port B: Write
        .CLKB(clk),
        .CEB(1'b1),
        .WEB(w_en),
        .ADB13(w_addr[10]), .ADB12(w_addr[9]), .ADB11(w_addr[8]), 
        .ADB10(w_addr[7]),  .ADB9(w_addr[6]),   .ADB8(w_addr[5]), 
        .ADB7(w_addr[4]),   .ADB6(w_addr[3]),   .ADB5(w_addr[2]), 
        .ADB4(w_addr[1]),   .ADB3(w_addr[0]),
        .ADB2(1'b0), .ADB1(1'b0), .ADB0(1'b0),
        .DIB8(1'b0), // Ignored 9th bit
        .DIB7(w_data[7]), .DIB6(w_data[6]), .DIB5(w_data[5]), .DIB4(w_data[4]),
        .DIB3(w_data[3]), .DIB2(w_data[2]), .DIB1(w_data[1]), .DIB0(w_data[0])
    );

endmodule
