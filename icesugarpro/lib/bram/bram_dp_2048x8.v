module bram_dp_2048x8
#(
	parameter WRITEMODE_A="NORMAL",
	parameter WRITEMODE_B="NORMAL",
	parameter REGMODE_A="NOREG",
	parameter REGMODE_B="NOREG"
)
(
    // Port A
    input         clk_a,
    input  [10:0] addr_a,
    input  [7:0]  din_a,
    input         we_a,
    output [7:0]  dout_a,

    // Port B
    input         clk_b,
    input  [10:0] addr_b,
    input  [7:0]  din_b,
    input         we_b,
    output [7:0]  dout_b
);

    DP16KD #(
        .DATA_WIDTH_A(9),
        .DATA_WIDTH_B(9),
        .WRITEMODE_A(WRITEMODE_A),
        .WRITEMODE_B(WRITEMODE_B),
        .REGMODE_A(REGMODE_A), // Set to "REG" for +1 cycle latency but better timing
        .REGMODE_B(REGMODE_B),
        .GSR("DISABLED")
    ) mem_inst (
        // Port A Connections
        .CLKA(clk_a),
        .CEA(1'b1),
        .OCEA(1'b1),
        .WEA(we_a),
        .RSTA(1'b0),
        // Address: For 9-bit mode, bits [10:0] map to ADA[13:3]
        .ADA13(addr_a[10]), .ADA12(addr_a[9]), .ADA11(addr_a[8]),
        .ADA10(addr_a[7]),  .ADA9(addr_a[6]),   .ADA8(addr_a[5]),
        .ADA7(addr_a[4]),   .ADA6(addr_a[3]),   .ADA5(addr_a[2]),
        .ADA4(addr_a[1]),   .ADA3(addr_a[0]),
        .ADA2(1'b0), .ADA1(1'b0), .ADA0(1'b0),
        // Data
        .DIA8(1'b0),
        .DIA7(din_a[7]), .DIA6(din_a[6]), .DIA5(din_a[5]), .DIA4(din_a[4]),
        .DIA3(din_a[3]), .DIA2(din_a[2]), .DIA1(din_a[1]), .DIA0(din_a[0]),
        .DOA8(), 
        .DOA7(dout_a[7]), .DOA6(dout_a[6]), .DOA5(dout_a[5]), .DOA4(dout_a[4]),
        .DOA3(dout_a[3]), .DOA2(dout_a[2]), .DOA1(dout_a[1]), .DOA0(dout_a[0]),

        // Port B Connections
        .CLKB(clk_b),
        .CEB(1'b1),
        .OCEB(1'b1),
        .WEB(we_b),
        .RSTB(1'b0),
        // Address
        .ADB13(addr_b[10]), .ADB12(addr_b[9]), .ADB11(addr_b[8]),
        .ADB10(addr_b[7]),  .ADB9(addr_b[6]),   .ADB8(addr_b[5]),
        .ADB7(addr_b[4]),   .ADB6(addr_b[3]),   .ADB5(addr_b[2]),
        .ADB4(addr_b[1]),   .ADB3(addr_b[0]),
        .ADB2(1'b0), .ADB1(1'b0), .ADB0(1'b0),
        // Data
        .DIB8(1'b0),
        .DIB7(din_b[7]), .DIB6(din_b[6]), .DIB5(din_b[5]), .DIB4(din_b[4]),
        .DIB3(din_b[3]), .DIB2(din_b[2]), .DIB1(din_b[1]), .DIB0(din_b[0]),
        .DOB8(),
        .DOB7(dout_b[7]), .DOB6(dout_b[6]), .DOB5(dout_b[5]), .DOB4(dout_b[4]),
        .DOB3(dout_b[3]), .DOB2(dout_b[2]), .DOB1(dout_b[1]), .DOB0(dout_b[0])
    );

endmodule

