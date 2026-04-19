//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//Tool Version: V1.9.11.03 Education
//Part Number: GW5A-LV25MG121NC1/I0
//Device: GW5A-25
//Device Version: A
//Created Time: Sun Apr 19 14:41:35 2026
`default_nettype wire
module boot_rom (dout, ad);

output [15:0] dout;
input [5:0] ad;

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
wire [0:0] rom16_inst_32_dout;
wire [1:1] rom16_inst_33_dout;
wire [2:2] rom16_inst_34_dout;
wire [3:3] rom16_inst_35_dout;
wire [4:4] rom16_inst_36_dout;
wire [5:5] rom16_inst_37_dout;
wire [6:6] rom16_inst_38_dout;
wire [7:7] rom16_inst_39_dout;
wire [8:8] rom16_inst_40_dout;
wire [9:9] rom16_inst_41_dout;
wire [10:10] rom16_inst_42_dout;
wire [11:11] rom16_inst_43_dout;
wire [12:12] rom16_inst_44_dout;
wire [13:13] rom16_inst_45_dout;
wire [14:14] rom16_inst_46_dout;
wire [15:15] rom16_inst_47_dout;
wire mux_o_0;
wire mux_o_3;
wire mux_o_6;
wire mux_o_9;
wire mux_o_12;
wire mux_o_15;
wire mux_o_18;
wire mux_o_21;
wire mux_o_24;
wire mux_o_27;
wire mux_o_30;
wire mux_o_33;
wire mux_o_36;
wire mux_o_39;
wire mux_o_42;
wire mux_o_45;

ROM16 rom16_inst_0 (
    .DO(rom16_inst_0_dout[0]),
    .AD(ad[3:0])
);

defparam rom16_inst_0.INIT_0 = 16'h0F6A;

ROM16 rom16_inst_1 (
    .DO(rom16_inst_1_dout[1]),
    .AD(ad[3:0])
);

defparam rom16_inst_1.INIT_0 = 16'hAFBA;

ROM16 rom16_inst_2 (
    .DO(rom16_inst_2_dout[2]),
    .AD(ad[3:0])
);

defparam rom16_inst_2.INIT_0 = 16'hCBFE;

ROM16 rom16_inst_3 (
    .DO(rom16_inst_3_dout[3]),
    .AD(ad[3:0])
);

defparam rom16_inst_3.INIT_0 = 16'hAFFE;

ROM16 rom16_inst_4 (
    .DO(rom16_inst_4_dout[4]),
    .AD(ad[3:0])
);

defparam rom16_inst_4.INIT_0 = 16'hAFFE;

ROM16 rom16_inst_5 (
    .DO(rom16_inst_5_dout[5]),
    .AD(ad[3:0])
);

defparam rom16_inst_5.INIT_0 = 16'h8FFE;

ROM16 rom16_inst_6 (
    .DO(rom16_inst_6_dout[6]),
    .AD(ad[3:0])
);

defparam rom16_inst_6.INIT_0 = 16'hAFFE;

ROM16 rom16_inst_7 (
    .DO(rom16_inst_7_dout[7]),
    .AD(ad[3:0])
);

defparam rom16_inst_7.INIT_0 = 16'hCFFE;

ROM16 rom16_inst_8 (
    .DO(rom16_inst_8_dout[8]),
    .AD(ad[3:0])
);

defparam rom16_inst_8.INIT_0 = 16'h9A3A;

ROM16 rom16_inst_9 (
    .DO(rom16_inst_9_dout[9]),
    .AD(ad[3:0])
);

defparam rom16_inst_9.INIT_0 = 16'hC366;

ROM16 rom16_inst_10 (
    .DO(rom16_inst_10_dout[10]),
    .AD(ad[3:0])
);

defparam rom16_inst_10.INIT_0 = 16'h6F66;

ROM16 rom16_inst_11 (
    .DO(rom16_inst_11_dout[11]),
    .AD(ad[3:0])
);

defparam rom16_inst_11.INIT_0 = 16'h0F66;

ROM16 rom16_inst_12 (
    .DO(rom16_inst_12_dout[12]),
    .AD(ad[3:0])
);

defparam rom16_inst_12.INIT_0 = 16'hC000;

ROM16 rom16_inst_13 (
    .DO(rom16_inst_13_dout[13]),
    .AD(ad[3:0])
);

defparam rom16_inst_13.INIT_0 = 16'h4090;

ROM16 rom16_inst_14 (
    .DO(rom16_inst_14_dout[14]),
    .AD(ad[3:0])
);

defparam rom16_inst_14.INIT_0 = 16'h4000;

ROM16 rom16_inst_15 (
    .DO(rom16_inst_15_dout[15]),
    .AD(ad[3:0])
);

defparam rom16_inst_15.INIT_0 = 16'h8090;

ROM16 rom16_inst_16 (
    .DO(rom16_inst_16_dout[0]),
    .AD(ad[3:0])
);

defparam rom16_inst_16.INIT_0 = 16'hE442;

ROM16 rom16_inst_17 (
    .DO(rom16_inst_17_dout[1]),
    .AD(ad[3:0])
);

defparam rom16_inst_17.INIT_0 = 16'h03BC;

ROM16 rom16_inst_18 (
    .DO(rom16_inst_18_dout[2]),
    .AD(ad[3:0])
);

defparam rom16_inst_18.INIT_0 = 16'h27FF;

ROM16 rom16_inst_19 (
    .DO(rom16_inst_19_dout[3]),
    .AD(ad[3:0])
);

defparam rom16_inst_19.INIT_0 = 16'h019E;

ROM16 rom16_inst_20 (
    .DO(rom16_inst_20_dout[4]),
    .AD(ad[3:0])
);

defparam rom16_inst_20.INIT_0 = 16'hFFBF;

ROM16 rom16_inst_21 (
    .DO(rom16_inst_21_dout[5]),
    .AD(ad[3:0])
);

defparam rom16_inst_21.INIT_0 = 16'hA7BF;

ROM16 rom16_inst_22 (
    .DO(rom16_inst_22_dout[6]),
    .AD(ad[3:0])
);

defparam rom16_inst_22.INIT_0 = 16'hF1DE;

ROM16 rom16_inst_23 (
    .DO(rom16_inst_23_dout[7]),
    .AD(ad[3:0])
);

defparam rom16_inst_23.INIT_0 = 16'h219E;

ROM16 rom16_inst_24 (
    .DO(rom16_inst_24_dout[8]),
    .AD(ad[3:0])
);

defparam rom16_inst_24.INIT_0 = 16'hEFFB;

ROM16 rom16_inst_25 (
    .DO(rom16_inst_25_dout[9]),
    .AD(ad[3:0])
);

defparam rom16_inst_25.INIT_0 = 16'h8F9C;

ROM16 rom16_inst_26 (
    .DO(rom16_inst_26_dout[10]),
    .AD(ad[3:0])
);

defparam rom16_inst_26.INIT_0 = 16'h2062;

ROM16 rom16_inst_27 (
    .DO(rom16_inst_27_dout[11]),
    .AD(ad[3:0])
);

defparam rom16_inst_27.INIT_0 = 16'h8000;

ROM16 rom16_inst_28 (
    .DO(rom16_inst_28_dout[12]),
    .AD(ad[3:0])
);

defparam rom16_inst_28.INIT_0 = 16'hF6EE;

ROM16 rom16_inst_29 (
    .DO(rom16_inst_29_dout[13]),
    .AD(ad[3:0])
);

defparam rom16_inst_29.INIT_0 = 16'hD951;

ROM16 rom16_inst_30 (
    .DO(rom16_inst_30_dout[14]),
    .AD(ad[3:0])
);

defparam rom16_inst_30.INIT_0 = 16'hF443;

ROM16 rom16_inst_31 (
    .DO(rom16_inst_31_dout[15]),
    .AD(ad[3:0])
);

defparam rom16_inst_31.INIT_0 = 16'h299E;

ROM16 rom16_inst_32 (
    .DO(rom16_inst_32_dout[0]),
    .AD(ad[3:0])
);

defparam rom16_inst_32.INIT_0 = 16'h6480;

ROM16 rom16_inst_33 (
    .DO(rom16_inst_33_dout[1]),
    .AD(ad[3:0])
);

defparam rom16_inst_33.INIT_0 = 16'h6366;

ROM16 rom16_inst_34 (
    .DO(rom16_inst_34_dout[2]),
    .AD(ad[3:0])
);

defparam rom16_inst_34.INIT_0 = 16'h67E1;

ROM16 rom16_inst_35 (
    .DO(rom16_inst_35_dout[3]),
    .AD(ad[3:0])
);

defparam rom16_inst_35.INIT_0 = 16'h4131;

ROM16 rom16_inst_36 (
    .DO(rom16_inst_36_dout[4]),
    .AD(ad[3:0])
);

defparam rom16_inst_36.INIT_0 = 16'h3F63;

ROM16 rom16_inst_37 (
    .DO(rom16_inst_37_dout[5]),
    .AD(ad[3:0])
);

defparam rom16_inst_37.INIT_0 = 16'h6760;

ROM16 rom16_inst_38 (
    .DO(rom16_inst_38_dout[6]),
    .AD(ad[3:0])
);

defparam rom16_inst_38.INIT_0 = 16'h71A1;

ROM16 rom16_inst_39 (
    .DO(rom16_inst_39_dout[7]),
    .AD(ad[3:0])
);

defparam rom16_inst_39.INIT_0 = 16'h6121;

ROM16 rom16_inst_40 (
    .DO(rom16_inst_40_dout[8]),
    .AD(ad[3:0])
);

defparam rom16_inst_40.INIT_0 = 16'h6FE3;

ROM16 rom16_inst_41 (
    .DO(rom16_inst_41_dout[9]),
    .AD(ad[3:0])
);

defparam rom16_inst_41.INIT_0 = 16'h0F21;

ROM16 rom16_inst_42 (
    .DO(rom16_inst_42_dout[10]),
    .AD(ad[3:0])
);

defparam rom16_inst_42.INIT_0 = 16'h20C4;

ROM16 rom16_inst_43 (
    .DO(rom16_inst_43_dout[11]),
    .AD(ad[3:0])
);

defparam rom16_inst_43.INIT_0 = 16'h0001;

ROM16 rom16_inst_44 (
    .DO(rom16_inst_44_dout[12]),
    .AD(ad[3:0])
);

defparam rom16_inst_44.INIT_0 = 16'h77EC;

ROM16 rom16_inst_45 (
    .DO(rom16_inst_45_dout[13]),
    .AD(ad[3:0])
);

defparam rom16_inst_45.INIT_0 = 16'h189B;

ROM16 rom16_inst_46 (
    .DO(rom16_inst_46_dout[14]),
    .AD(ad[3:0])
);

defparam rom16_inst_46.INIT_0 = 16'h7496;

ROM16 rom16_inst_47 (
    .DO(rom16_inst_47_dout[15]),
    .AD(ad[3:0])
);

defparam rom16_inst_47.INIT_0 = 16'h6935;

MUX2 mux_inst_0 (
  .O(mux_o_0),
  .I0(rom16_inst_0_dout[0]),
  .I1(rom16_inst_16_dout[0]),
  .S0(ad[4])
);
MUX2 mux_inst_2 (
  .O(dout[0]),
  .I0(mux_o_0),
  .I1(rom16_inst_32_dout[0]),
  .S0(ad[5])
);
MUX2 mux_inst_3 (
  .O(mux_o_3),
  .I0(rom16_inst_1_dout[1]),
  .I1(rom16_inst_17_dout[1]),
  .S0(ad[4])
);
MUX2 mux_inst_5 (
  .O(dout[1]),
  .I0(mux_o_3),
  .I1(rom16_inst_33_dout[1]),
  .S0(ad[5])
);
MUX2 mux_inst_6 (
  .O(mux_o_6),
  .I0(rom16_inst_2_dout[2]),
  .I1(rom16_inst_18_dout[2]),
  .S0(ad[4])
);
MUX2 mux_inst_8 (
  .O(dout[2]),
  .I0(mux_o_6),
  .I1(rom16_inst_34_dout[2]),
  .S0(ad[5])
);
MUX2 mux_inst_9 (
  .O(mux_o_9),
  .I0(rom16_inst_3_dout[3]),
  .I1(rom16_inst_19_dout[3]),
  .S0(ad[4])
);
MUX2 mux_inst_11 (
  .O(dout[3]),
  .I0(mux_o_9),
  .I1(rom16_inst_35_dout[3]),
  .S0(ad[5])
);
MUX2 mux_inst_12 (
  .O(mux_o_12),
  .I0(rom16_inst_4_dout[4]),
  .I1(rom16_inst_20_dout[4]),
  .S0(ad[4])
);
MUX2 mux_inst_14 (
  .O(dout[4]),
  .I0(mux_o_12),
  .I1(rom16_inst_36_dout[4]),
  .S0(ad[5])
);
MUX2 mux_inst_15 (
  .O(mux_o_15),
  .I0(rom16_inst_5_dout[5]),
  .I1(rom16_inst_21_dout[5]),
  .S0(ad[4])
);
MUX2 mux_inst_17 (
  .O(dout[5]),
  .I0(mux_o_15),
  .I1(rom16_inst_37_dout[5]),
  .S0(ad[5])
);
MUX2 mux_inst_18 (
  .O(mux_o_18),
  .I0(rom16_inst_6_dout[6]),
  .I1(rom16_inst_22_dout[6]),
  .S0(ad[4])
);
MUX2 mux_inst_20 (
  .O(dout[6]),
  .I0(mux_o_18),
  .I1(rom16_inst_38_dout[6]),
  .S0(ad[5])
);
MUX2 mux_inst_21 (
  .O(mux_o_21),
  .I0(rom16_inst_7_dout[7]),
  .I1(rom16_inst_23_dout[7]),
  .S0(ad[4])
);
MUX2 mux_inst_23 (
  .O(dout[7]),
  .I0(mux_o_21),
  .I1(rom16_inst_39_dout[7]),
  .S0(ad[5])
);
MUX2 mux_inst_24 (
  .O(mux_o_24),
  .I0(rom16_inst_8_dout[8]),
  .I1(rom16_inst_24_dout[8]),
  .S0(ad[4])
);
MUX2 mux_inst_26 (
  .O(dout[8]),
  .I0(mux_o_24),
  .I1(rom16_inst_40_dout[8]),
  .S0(ad[5])
);
MUX2 mux_inst_27 (
  .O(mux_o_27),
  .I0(rom16_inst_9_dout[9]),
  .I1(rom16_inst_25_dout[9]),
  .S0(ad[4])
);
MUX2 mux_inst_29 (
  .O(dout[9]),
  .I0(mux_o_27),
  .I1(rom16_inst_41_dout[9]),
  .S0(ad[5])
);
MUX2 mux_inst_30 (
  .O(mux_o_30),
  .I0(rom16_inst_10_dout[10]),
  .I1(rom16_inst_26_dout[10]),
  .S0(ad[4])
);
MUX2 mux_inst_32 (
  .O(dout[10]),
  .I0(mux_o_30),
  .I1(rom16_inst_42_dout[10]),
  .S0(ad[5])
);
MUX2 mux_inst_33 (
  .O(mux_o_33),
  .I0(rom16_inst_11_dout[11]),
  .I1(rom16_inst_27_dout[11]),
  .S0(ad[4])
);
MUX2 mux_inst_35 (
  .O(dout[11]),
  .I0(mux_o_33),
  .I1(rom16_inst_43_dout[11]),
  .S0(ad[5])
);
MUX2 mux_inst_36 (
  .O(mux_o_36),
  .I0(rom16_inst_12_dout[12]),
  .I1(rom16_inst_28_dout[12]),
  .S0(ad[4])
);
MUX2 mux_inst_38 (
  .O(dout[12]),
  .I0(mux_o_36),
  .I1(rom16_inst_44_dout[12]),
  .S0(ad[5])
);
MUX2 mux_inst_39 (
  .O(mux_o_39),
  .I0(rom16_inst_13_dout[13]),
  .I1(rom16_inst_29_dout[13]),
  .S0(ad[4])
);
MUX2 mux_inst_41 (
  .O(dout[13]),
  .I0(mux_o_39),
  .I1(rom16_inst_45_dout[13]),
  .S0(ad[5])
);
MUX2 mux_inst_42 (
  .O(mux_o_42),
  .I0(rom16_inst_14_dout[14]),
  .I1(rom16_inst_30_dout[14]),
  .S0(ad[4])
);
MUX2 mux_inst_44 (
  .O(dout[14]),
  .I0(mux_o_42),
  .I1(rom16_inst_46_dout[14]),
  .S0(ad[5])
);
MUX2 mux_inst_45 (
  .O(mux_o_45),
  .I0(rom16_inst_15_dout[15]),
  .I1(rom16_inst_31_dout[15]),
  .S0(ad[4])
);
MUX2 mux_inst_47 (
  .O(dout[15]),
  .I0(mux_o_45),
  .I1(rom16_inst_47_dout[15]),
  .S0(ad[5])
);
endmodule //boot_rom
