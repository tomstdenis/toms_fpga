//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//Tool Version: V1.9.11.03 Education
//Part Number: GW1NZ-LV1QN48C6/I5
//Device: GW1NZ-1
//Created Time: Sun Apr 19 13:54:22 2026
`default_nettype wire
module Gowin_ROM16 (dout, ad);

output [15:0] dout;
input [4:0] ad;

wire [0:0] rom16_inst_0_dout;
wire [1:1] rom16_inst_1_dout;
wire [2:2] rom16_inst_2_dout;
wire [3:3] rom16_inst_3_dout;
wire [4:4] rom16_inst_4_dout;
wire [5:5] rom16_inst_5_dout;
wire [6:6] rom16_inst_6_dout;
wire [7:7] rom16_inst_7_dout;
wire [8:8] rom16_inst_8_dout;
wire [9:9] rom16_inst_9_dout;
wire [10:10] rom16_inst_10_dout;
wire [11:11] rom16_inst_11_dout;
wire [12:12] rom16_inst_12_dout;
wire [13:13] rom16_inst_13_dout;
wire [14:14] rom16_inst_14_dout;
wire [15:15] rom16_inst_15_dout;
wire [0:0] rom16_inst_16_dout;
wire [1:1] rom16_inst_17_dout;
wire [2:2] rom16_inst_18_dout;
wire [3:3] rom16_inst_19_dout;
wire [4:4] rom16_inst_20_dout;
wire [5:5] rom16_inst_21_dout;
wire [6:6] rom16_inst_22_dout;
wire [7:7] rom16_inst_23_dout;
wire [8:8] rom16_inst_24_dout;
wire [9:9] rom16_inst_25_dout;
wire [10:10] rom16_inst_26_dout;
wire [11:11] rom16_inst_27_dout;
wire [12:12] rom16_inst_28_dout;
wire [13:13] rom16_inst_29_dout;
wire [14:14] rom16_inst_30_dout;
wire [15:15] rom16_inst_31_dout;

ROM16 rom16_inst_0 (
    .DO(rom16_inst_0_dout[0]),
    .AD(ad[3:0])
);

defparam rom16_inst_0.INIT_0 = 16'h6083;

ROM16 rom16_inst_1 (
    .DO(rom16_inst_1_dout[1]),
    .AD(ad[3:0])
);

defparam rom16_inst_1.INIT_0 = 16'hA733;

ROM16 rom16_inst_2 (
    .DO(rom16_inst_2_dout[2]),
    .AD(ad[3:0])
);

defparam rom16_inst_2.INIT_0 = 16'h07E3;

ROM16 rom16_inst_3 (
    .DO(rom16_inst_3_dout[3]),
    .AD(ad[3:0])
);

defparam rom16_inst_3.INIT_0 = 16'h27B3;

ROM16 rom16_inst_4 (
    .DO(rom16_inst_4_dout[4]),
    .AD(ad[3:0])
);

defparam rom16_inst_4.INIT_0 = 16'hFFF3;

ROM16 rom16_inst_5 (
    .DO(rom16_inst_5_dout[5]),
    .AD(ad[3:0])
);

defparam rom16_inst_5.INIT_0 = 16'h27E3;

ROM16 rom16_inst_6 (
    .DO(rom16_inst_6_dout[6]),
    .AD(ad[3:0])
);

defparam rom16_inst_6.INIT_0 = 16'h77B3;

ROM16 rom16_inst_7 (
    .DO(rom16_inst_7_dout[7]),
    .AD(ad[3:0])
);

defparam rom16_inst_7.INIT_0 = 16'h27A3;

ROM16 rom16_inst_8 (
    .DO(rom16_inst_8_dout[8]),
    .AD(ad[3:0])
);

defparam rom16_inst_8.INIT_0 = 16'hEEEA;

ROM16 rom16_inst_9 (
    .DO(rom16_inst_9_dout[9]),
    .AD(ad[3:0])
);

defparam rom16_inst_9.INIT_0 = 16'h0F23;

ROM16 rom16_inst_10 (
    .DO(rom16_inst_10_dout[10]),
    .AD(ad[3:0])
);

defparam rom16_inst_10.INIT_0 = 16'h2093;

ROM16 rom16_inst_11 (
    .DO(rom16_inst_11_dout[11]),
    .AD(ad[3:0])
);

defparam rom16_inst_11.INIT_0 = 16'h0003;

ROM16 rom16_inst_12 (
    .DO(rom16_inst_12_dout[12]),
    .AD(ad[3:0])
);

defparam rom16_inst_12.INIT_0 = 16'h73A0;

ROM16 rom16_inst_13 (
    .DO(rom16_inst_13_dout[13]),
    .AD(ad[3:0])
);

defparam rom16_inst_13.INIT_0 = 16'hDC40;

ROM16 rom16_inst_14 (
    .DO(rom16_inst_14_dout[14]),
    .AD(ad[3:0])
);

defparam rom16_inst_14.INIT_0 = 16'hF0C0;

ROM16 rom16_inst_15 (
    .DO(rom16_inst_15_dout[15]),
    .AD(ad[3:0])
);

defparam rom16_inst_15.INIT_0 = 16'h2FA0;

ROM16 rom16_inst_16 (
    .DO(rom16_inst_16_dout[0]),
    .AD(ad[3:0])
);

defparam rom16_inst_16.INIT_0 = 16'h0000;

ROM16 rom16_inst_17 (
    .DO(rom16_inst_17_dout[1]),
    .AD(ad[3:0])
);

defparam rom16_inst_17.INIT_0 = 16'h0089;

ROM16 rom16_inst_18 (
    .DO(rom16_inst_18_dout[2]),
    .AD(ad[3:0])
);

defparam rom16_inst_18.INIT_0 = 16'h00C8;

ROM16 rom16_inst_19 (
    .DO(rom16_inst_19_dout[3]),
    .AD(ad[3:0])
);

defparam rom16_inst_19.INIT_0 = 16'h004C;

ROM16 rom16_inst_20 (
    .DO(rom16_inst_20_dout[4]),
    .AD(ad[3:0])
);

defparam rom16_inst_20.INIT_0 = 16'h00F8;

ROM16 rom16_inst_21 (
    .DO(rom16_inst_21_dout[5]),
    .AD(ad[3:0])
);

defparam rom16_inst_21.INIT_0 = 16'h00C8;

ROM16 rom16_inst_22 (
    .DO(rom16_inst_22_dout[6]),
    .AD(ad[3:0])
);

defparam rom16_inst_22.INIT_0 = 16'h00E8;

ROM16 rom16_inst_23 (
    .DO(rom16_inst_23_dout[7]),
    .AD(ad[3:0])
);

defparam rom16_inst_23.INIT_0 = 16'h00C8;

ROM16 rom16_inst_24 (
    .DO(rom16_inst_24_dout[8]),
    .AD(ad[3:0])
);

defparam rom16_inst_24.INIT_0 = 16'h00D8;

ROM16 rom16_inst_25 (
    .DO(rom16_inst_25_dout[9]),
    .AD(ad[3:0])
);

defparam rom16_inst_25.INIT_0 = 16'h0018;

ROM16 rom16_inst_26 (
    .DO(rom16_inst_26_dout[10]),
    .AD(ad[3:0])
);

defparam rom16_inst_26.INIT_0 = 16'h0041;

ROM16 rom16_inst_27 (
    .DO(rom16_inst_27_dout[11]),
    .AD(ad[3:0])
);

defparam rom16_inst_27.INIT_0 = 16'h0000;

ROM16 rom16_inst_28 (
    .DO(rom16_inst_28_dout[12]),
    .AD(ad[3:0])
);

defparam rom16_inst_28.INIT_0 = 16'h00EB;

ROM16 rom16_inst_29 (
    .DO(rom16_inst_29_dout[13]),
    .AD(ad[3:0])
);

defparam rom16_inst_29.INIT_0 = 16'h0036;

ROM16 rom16_inst_30 (
    .DO(rom16_inst_30_dout[14]),
    .AD(ad[3:0])
);

defparam rom16_inst_30.INIT_0 = 16'h00E5;

ROM16 rom16_inst_31 (
    .DO(rom16_inst_31_dout[15]),
    .AD(ad[3:0])
);

defparam rom16_inst_31.INIT_0 = 16'h00DD;

MUX2 mux_inst_0 (
  .O(dout[0]),
  .I0(rom16_inst_0_dout[0]),
  .I1(rom16_inst_16_dout[0]),
  .S0(ad[4])
);
MUX2 mux_inst_1 (
  .O(dout[1]),
  .I0(rom16_inst_1_dout[1]),
  .I1(rom16_inst_17_dout[1]),
  .S0(ad[4])
);
MUX2 mux_inst_2 (
  .O(dout[2]),
  .I0(rom16_inst_2_dout[2]),
  .I1(rom16_inst_18_dout[2]),
  .S0(ad[4])
);
MUX2 mux_inst_3 (
  .O(dout[3]),
  .I0(rom16_inst_3_dout[3]),
  .I1(rom16_inst_19_dout[3]),
  .S0(ad[4])
);
MUX2 mux_inst_4 (
  .O(dout[4]),
  .I0(rom16_inst_4_dout[4]),
  .I1(rom16_inst_20_dout[4]),
  .S0(ad[4])
);
MUX2 mux_inst_5 (
  .O(dout[5]),
  .I0(rom16_inst_5_dout[5]),
  .I1(rom16_inst_21_dout[5]),
  .S0(ad[4])
);
MUX2 mux_inst_6 (
  .O(dout[6]),
  .I0(rom16_inst_6_dout[6]),
  .I1(rom16_inst_22_dout[6]),
  .S0(ad[4])
);
MUX2 mux_inst_7 (
  .O(dout[7]),
  .I0(rom16_inst_7_dout[7]),
  .I1(rom16_inst_23_dout[7]),
  .S0(ad[4])
);
MUX2 mux_inst_8 (
  .O(dout[8]),
  .I0(rom16_inst_8_dout[8]),
  .I1(rom16_inst_24_dout[8]),
  .S0(ad[4])
);
MUX2 mux_inst_9 (
  .O(dout[9]),
  .I0(rom16_inst_9_dout[9]),
  .I1(rom16_inst_25_dout[9]),
  .S0(ad[4])
);
MUX2 mux_inst_10 (
  .O(dout[10]),
  .I0(rom16_inst_10_dout[10]),
  .I1(rom16_inst_26_dout[10]),
  .S0(ad[4])
);
MUX2 mux_inst_11 (
  .O(dout[11]),
  .I0(rom16_inst_11_dout[11]),
  .I1(rom16_inst_27_dout[11]),
  .S0(ad[4])
);
MUX2 mux_inst_12 (
  .O(dout[12]),
  .I0(rom16_inst_12_dout[12]),
  .I1(rom16_inst_28_dout[12]),
  .S0(ad[4])
);
MUX2 mux_inst_13 (
  .O(dout[13]),
  .I0(rom16_inst_13_dout[13]),
  .I1(rom16_inst_29_dout[13]),
  .S0(ad[4])
);
MUX2 mux_inst_14 (
  .O(dout[14]),
  .I0(rom16_inst_14_dout[14]),
  .I1(rom16_inst_30_dout[14]),
  .S0(ad[4])
);
MUX2 mux_inst_15 (
  .O(dout[15]),
  .I0(rom16_inst_15_dout[15]),
  .I1(rom16_inst_31_dout[15]),
  .S0(ad[4])
);
endmodule //Gowin_ROM16
