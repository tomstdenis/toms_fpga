//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//Tool Version: V1.9.11.03 Education
//Part Number: GW5A-LV25MG121NC1/I0
//Device: GW5A-25
//Device Version: A
//Created Time: Fri May 15 18:43:02 2026
`default_nettype wire

module cflea_main_mem (douta, doutb, clka, ocea, cea, reseta, wrea, clkb, oceb, ceb, resetb, wreb, ada, dina, adb, dinb);

output [7:0] douta;
output [7:0] doutb;
input clka;
input ocea;
input cea;
input reseta;
input wrea;
input clkb;
input oceb;
input ceb;
input resetb;
input wreb;
input [15:0] ada;
input [7:0] dina;
input [15:0] adb;
input [7:0] dinb;

wire lut_f_0;
wire lut_f_1;
wire [14:0] dpb_inst_0_douta_w;
wire [0:0] dpb_inst_0_douta;
wire [14:0] dpb_inst_0_doutb_w;
wire [0:0] dpb_inst_0_doutb;
wire [14:0] dpb_inst_1_douta_w;
wire [0:0] dpb_inst_1_douta;
wire [14:0] dpb_inst_1_doutb_w;
wire [0:0] dpb_inst_1_doutb;
wire [14:0] dpb_inst_2_douta_w;
wire [1:1] dpb_inst_2_douta;
wire [14:0] dpb_inst_2_doutb_w;
wire [1:1] dpb_inst_2_doutb;
wire [14:0] dpb_inst_3_douta_w;
wire [1:1] dpb_inst_3_douta;
wire [14:0] dpb_inst_3_doutb_w;
wire [1:1] dpb_inst_3_doutb;
wire [14:0] dpb_inst_4_douta_w;
wire [2:2] dpb_inst_4_douta;
wire [14:0] dpb_inst_4_doutb_w;
wire [2:2] dpb_inst_4_doutb;
wire [14:0] dpb_inst_5_douta_w;
wire [2:2] dpb_inst_5_douta;
wire [14:0] dpb_inst_5_doutb_w;
wire [2:2] dpb_inst_5_doutb;
wire [14:0] dpb_inst_6_douta_w;
wire [3:3] dpb_inst_6_douta;
wire [14:0] dpb_inst_6_doutb_w;
wire [3:3] dpb_inst_6_doutb;
wire [14:0] dpb_inst_7_douta_w;
wire [3:3] dpb_inst_7_douta;
wire [14:0] dpb_inst_7_doutb_w;
wire [3:3] dpb_inst_7_doutb;
wire [14:0] dpb_inst_8_douta_w;
wire [0:0] dpb_inst_8_douta;
wire [14:0] dpb_inst_8_doutb_w;
wire [0:0] dpb_inst_8_doutb;
wire [14:0] dpb_inst_9_douta_w;
wire [1:1] dpb_inst_9_douta;
wire [14:0] dpb_inst_9_doutb_w;
wire [1:1] dpb_inst_9_doutb;
wire [14:0] dpb_inst_10_douta_w;
wire [2:2] dpb_inst_10_douta;
wire [14:0] dpb_inst_10_doutb_w;
wire [2:2] dpb_inst_10_doutb;
wire [14:0] dpb_inst_11_douta_w;
wire [3:3] dpb_inst_11_douta;
wire [14:0] dpb_inst_11_doutb_w;
wire [3:3] dpb_inst_11_doutb;
wire [13:0] dpb_inst_12_douta_w;
wire [1:0] dpb_inst_12_douta;
wire [13:0] dpb_inst_12_doutb_w;
wire [1:0] dpb_inst_12_doutb;
wire [13:0] dpb_inst_13_douta_w;
wire [3:2] dpb_inst_13_douta;
wire [13:0] dpb_inst_13_doutb_w;
wire [3:2] dpb_inst_13_doutb;
wire [11:0] dpb_inst_14_douta_w;
wire [3:0] dpb_inst_14_douta;
wire [11:0] dpb_inst_14_doutb_w;
wire [3:0] dpb_inst_14_doutb;
wire [14:0] dpb_inst_15_douta_w;
wire [4:4] dpb_inst_15_douta;
wire [14:0] dpb_inst_15_doutb_w;
wire [4:4] dpb_inst_15_doutb;
wire [14:0] dpb_inst_16_douta_w;
wire [4:4] dpb_inst_16_douta;
wire [14:0] dpb_inst_16_doutb_w;
wire [4:4] dpb_inst_16_doutb;
wire [14:0] dpb_inst_17_douta_w;
wire [5:5] dpb_inst_17_douta;
wire [14:0] dpb_inst_17_doutb_w;
wire [5:5] dpb_inst_17_doutb;
wire [14:0] dpb_inst_18_douta_w;
wire [5:5] dpb_inst_18_douta;
wire [14:0] dpb_inst_18_doutb_w;
wire [5:5] dpb_inst_18_doutb;
wire [14:0] dpb_inst_19_douta_w;
wire [6:6] dpb_inst_19_douta;
wire [14:0] dpb_inst_19_doutb_w;
wire [6:6] dpb_inst_19_doutb;
wire [14:0] dpb_inst_20_douta_w;
wire [6:6] dpb_inst_20_douta;
wire [14:0] dpb_inst_20_doutb_w;
wire [6:6] dpb_inst_20_doutb;
wire [14:0] dpb_inst_21_douta_w;
wire [7:7] dpb_inst_21_douta;
wire [14:0] dpb_inst_21_doutb_w;
wire [7:7] dpb_inst_21_doutb;
wire [14:0] dpb_inst_22_douta_w;
wire [7:7] dpb_inst_22_douta;
wire [14:0] dpb_inst_22_doutb_w;
wire [7:7] dpb_inst_22_doutb;
wire [14:0] dpb_inst_23_douta_w;
wire [4:4] dpb_inst_23_douta;
wire [14:0] dpb_inst_23_doutb_w;
wire [4:4] dpb_inst_23_doutb;
wire [14:0] dpb_inst_24_douta_w;
wire [5:5] dpb_inst_24_douta;
wire [14:0] dpb_inst_24_doutb_w;
wire [5:5] dpb_inst_24_doutb;
wire [14:0] dpb_inst_25_douta_w;
wire [6:6] dpb_inst_25_douta;
wire [14:0] dpb_inst_25_doutb_w;
wire [6:6] dpb_inst_25_doutb;
wire [14:0] dpb_inst_26_douta_w;
wire [7:7] dpb_inst_26_douta;
wire [14:0] dpb_inst_26_doutb_w;
wire [7:7] dpb_inst_26_doutb;
wire [13:0] dpb_inst_27_douta_w;
wire [5:4] dpb_inst_27_douta;
wire [13:0] dpb_inst_27_doutb_w;
wire [5:4] dpb_inst_27_doutb;
wire [13:0] dpb_inst_28_douta_w;
wire [7:6] dpb_inst_28_douta;
wire [13:0] dpb_inst_28_doutb_w;
wire [7:6] dpb_inst_28_doutb;
wire [11:0] dpb_inst_29_douta_w;
wire [7:4] dpb_inst_29_douta;
wire [11:0] dpb_inst_29_doutb_w;
wire [7:4] dpb_inst_29_doutb;
wire dff_q_0;
wire dff_q_1;
wire dff_q_2;
wire dff_q_3;
wire dff_q_4;
wire dff_q_5;
wire mux_o_8;
wire mux_o_9;
wire mux_o_10;
wire mux_o_20;
wire mux_o_21;
wire mux_o_22;
wire mux_o_32;
wire mux_o_33;
wire mux_o_34;
wire mux_o_44;
wire mux_o_45;
wire mux_o_46;
wire mux_o_56;
wire mux_o_57;
wire mux_o_58;
wire mux_o_68;
wire mux_o_69;
wire mux_o_70;
wire mux_o_80;
wire mux_o_81;
wire mux_o_82;
wire mux_o_92;
wire mux_o_93;
wire mux_o_94;
wire mux_o_104;
wire mux_o_105;
wire mux_o_106;
wire mux_o_116;
wire mux_o_117;
wire mux_o_118;
wire mux_o_128;
wire mux_o_129;
wire mux_o_130;
wire mux_o_140;
wire mux_o_141;
wire mux_o_142;
wire mux_o_152;
wire mux_o_153;
wire mux_o_154;
wire mux_o_164;
wire mux_o_165;
wire mux_o_166;
wire mux_o_176;
wire mux_o_177;
wire mux_o_178;
wire mux_o_188;
wire mux_o_189;
wire mux_o_190;
wire cea_w;
wire ceb_w;
wire gw_gnd;

assign cea_w = ~wrea & cea;
assign ceb_w = ~wreb & ceb;
assign gw_gnd = 1'b0;

LUT4 lut_inst_0 (
  .F(lut_f_0),
  .I0(ada[12]),
  .I1(ada[13]),
  .I2(ada[14]),
  .I3(ada[15])
);
defparam lut_inst_0.INIT = 16'h4000;
LUT4 lut_inst_1 (
  .F(lut_f_1),
  .I0(adb[12]),
  .I1(adb[13]),
  .I2(adb[14]),
  .I3(adb[15])
);
defparam lut_inst_1.INIT = 16'h4000;
DPB dpb_inst_0 (
    .DOA({dpb_inst_0_douta_w[14:0],dpb_inst_0_douta[0]}),
    .DOB({dpb_inst_0_doutb_w[14:0],dpb_inst_0_doutb[0]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[0]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[0]})
);

defparam dpb_inst_0.READ_MODE0 = 1'b0;
defparam dpb_inst_0.READ_MODE1 = 1'b0;
defparam dpb_inst_0.WRITE_MODE0 = 2'b00;
defparam dpb_inst_0.WRITE_MODE1 = 2'b00;
defparam dpb_inst_0.BIT_WIDTH_0 = 1;
defparam dpb_inst_0.BIT_WIDTH_1 = 1;
defparam dpb_inst_0.BLK_SEL_0 = 3'b000;
defparam dpb_inst_0.BLK_SEL_1 = 3'b000;
defparam dpb_inst_0.RESET_MODE = "SYNC";

DPB dpb_inst_1 (
    .DOA({dpb_inst_1_douta_w[14:0],dpb_inst_1_douta[0]}),
    .DOB({dpb_inst_1_doutb_w[14:0],dpb_inst_1_doutb[0]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[0]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[0]})
);

defparam dpb_inst_1.READ_MODE0 = 1'b0;
defparam dpb_inst_1.READ_MODE1 = 1'b0;
defparam dpb_inst_1.WRITE_MODE0 = 2'b00;
defparam dpb_inst_1.WRITE_MODE1 = 2'b00;
defparam dpb_inst_1.BIT_WIDTH_0 = 1;
defparam dpb_inst_1.BIT_WIDTH_1 = 1;
defparam dpb_inst_1.BLK_SEL_0 = 3'b001;
defparam dpb_inst_1.BLK_SEL_1 = 3'b001;
defparam dpb_inst_1.RESET_MODE = "SYNC";

DPB dpb_inst_2 (
    .DOA({dpb_inst_2_douta_w[14:0],dpb_inst_2_douta[1]}),
    .DOB({dpb_inst_2_doutb_w[14:0],dpb_inst_2_doutb[1]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[1]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[1]})
);

defparam dpb_inst_2.READ_MODE0 = 1'b0;
defparam dpb_inst_2.READ_MODE1 = 1'b0;
defparam dpb_inst_2.WRITE_MODE0 = 2'b00;
defparam dpb_inst_2.WRITE_MODE1 = 2'b00;
defparam dpb_inst_2.BIT_WIDTH_0 = 1;
defparam dpb_inst_2.BIT_WIDTH_1 = 1;
defparam dpb_inst_2.BLK_SEL_0 = 3'b000;
defparam dpb_inst_2.BLK_SEL_1 = 3'b000;
defparam dpb_inst_2.RESET_MODE = "SYNC";

DPB dpb_inst_3 (
    .DOA({dpb_inst_3_douta_w[14:0],dpb_inst_3_douta[1]}),
    .DOB({dpb_inst_3_doutb_w[14:0],dpb_inst_3_doutb[1]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[1]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[1]})
);

defparam dpb_inst_3.READ_MODE0 = 1'b0;
defparam dpb_inst_3.READ_MODE1 = 1'b0;
defparam dpb_inst_3.WRITE_MODE0 = 2'b00;
defparam dpb_inst_3.WRITE_MODE1 = 2'b00;
defparam dpb_inst_3.BIT_WIDTH_0 = 1;
defparam dpb_inst_3.BIT_WIDTH_1 = 1;
defparam dpb_inst_3.BLK_SEL_0 = 3'b001;
defparam dpb_inst_3.BLK_SEL_1 = 3'b001;
defparam dpb_inst_3.RESET_MODE = "SYNC";

DPB dpb_inst_4 (
    .DOA({dpb_inst_4_douta_w[14:0],dpb_inst_4_douta[2]}),
    .DOB({dpb_inst_4_doutb_w[14:0],dpb_inst_4_doutb[2]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[2]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[2]})
);

defparam dpb_inst_4.READ_MODE0 = 1'b0;
defparam dpb_inst_4.READ_MODE1 = 1'b0;
defparam dpb_inst_4.WRITE_MODE0 = 2'b00;
defparam dpb_inst_4.WRITE_MODE1 = 2'b00;
defparam dpb_inst_4.BIT_WIDTH_0 = 1;
defparam dpb_inst_4.BIT_WIDTH_1 = 1;
defparam dpb_inst_4.BLK_SEL_0 = 3'b000;
defparam dpb_inst_4.BLK_SEL_1 = 3'b000;
defparam dpb_inst_4.RESET_MODE = "SYNC";

DPB dpb_inst_5 (
    .DOA({dpb_inst_5_douta_w[14:0],dpb_inst_5_douta[2]}),
    .DOB({dpb_inst_5_doutb_w[14:0],dpb_inst_5_doutb[2]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[2]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[2]})
);

defparam dpb_inst_5.READ_MODE0 = 1'b0;
defparam dpb_inst_5.READ_MODE1 = 1'b0;
defparam dpb_inst_5.WRITE_MODE0 = 2'b00;
defparam dpb_inst_5.WRITE_MODE1 = 2'b00;
defparam dpb_inst_5.BIT_WIDTH_0 = 1;
defparam dpb_inst_5.BIT_WIDTH_1 = 1;
defparam dpb_inst_5.BLK_SEL_0 = 3'b001;
defparam dpb_inst_5.BLK_SEL_1 = 3'b001;
defparam dpb_inst_5.RESET_MODE = "SYNC";

DPB dpb_inst_6 (
    .DOA({dpb_inst_6_douta_w[14:0],dpb_inst_6_douta[3]}),
    .DOB({dpb_inst_6_doutb_w[14:0],dpb_inst_6_doutb[3]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[3]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[3]})
);

defparam dpb_inst_6.READ_MODE0 = 1'b0;
defparam dpb_inst_6.READ_MODE1 = 1'b0;
defparam dpb_inst_6.WRITE_MODE0 = 2'b00;
defparam dpb_inst_6.WRITE_MODE1 = 2'b00;
defparam dpb_inst_6.BIT_WIDTH_0 = 1;
defparam dpb_inst_6.BIT_WIDTH_1 = 1;
defparam dpb_inst_6.BLK_SEL_0 = 3'b000;
defparam dpb_inst_6.BLK_SEL_1 = 3'b000;
defparam dpb_inst_6.RESET_MODE = "SYNC";

DPB dpb_inst_7 (
    .DOA({dpb_inst_7_douta_w[14:0],dpb_inst_7_douta[3]}),
    .DOB({dpb_inst_7_doutb_w[14:0],dpb_inst_7_doutb[3]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[3]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[3]})
);

defparam dpb_inst_7.READ_MODE0 = 1'b0;
defparam dpb_inst_7.READ_MODE1 = 1'b0;
defparam dpb_inst_7.WRITE_MODE0 = 2'b00;
defparam dpb_inst_7.WRITE_MODE1 = 2'b00;
defparam dpb_inst_7.BIT_WIDTH_0 = 1;
defparam dpb_inst_7.BIT_WIDTH_1 = 1;
defparam dpb_inst_7.BLK_SEL_0 = 3'b001;
defparam dpb_inst_7.BLK_SEL_1 = 3'b001;
defparam dpb_inst_7.RESET_MODE = "SYNC";

DPB dpb_inst_8 (
    .DOA({dpb_inst_8_douta_w[14:0],dpb_inst_8_douta[0]}),
    .DOB({dpb_inst_8_doutb_w[14:0],dpb_inst_8_doutb[0]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[0]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[0]})
);

defparam dpb_inst_8.READ_MODE0 = 1'b0;
defparam dpb_inst_8.READ_MODE1 = 1'b0;
defparam dpb_inst_8.WRITE_MODE0 = 2'b00;
defparam dpb_inst_8.WRITE_MODE1 = 2'b00;
defparam dpb_inst_8.BIT_WIDTH_0 = 1;
defparam dpb_inst_8.BIT_WIDTH_1 = 1;
defparam dpb_inst_8.BLK_SEL_0 = 3'b010;
defparam dpb_inst_8.BLK_SEL_1 = 3'b010;
defparam dpb_inst_8.RESET_MODE = "SYNC";

DPB dpb_inst_9 (
    .DOA({dpb_inst_9_douta_w[14:0],dpb_inst_9_douta[1]}),
    .DOB({dpb_inst_9_doutb_w[14:0],dpb_inst_9_doutb[1]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[1]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[1]})
);

defparam dpb_inst_9.READ_MODE0 = 1'b0;
defparam dpb_inst_9.READ_MODE1 = 1'b0;
defparam dpb_inst_9.WRITE_MODE0 = 2'b00;
defparam dpb_inst_9.WRITE_MODE1 = 2'b00;
defparam dpb_inst_9.BIT_WIDTH_0 = 1;
defparam dpb_inst_9.BIT_WIDTH_1 = 1;
defparam dpb_inst_9.BLK_SEL_0 = 3'b010;
defparam dpb_inst_9.BLK_SEL_1 = 3'b010;
defparam dpb_inst_9.RESET_MODE = "SYNC";

DPB dpb_inst_10 (
    .DOA({dpb_inst_10_douta_w[14:0],dpb_inst_10_douta[2]}),
    .DOB({dpb_inst_10_doutb_w[14:0],dpb_inst_10_doutb[2]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[2]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[2]})
);

defparam dpb_inst_10.READ_MODE0 = 1'b0;
defparam dpb_inst_10.READ_MODE1 = 1'b0;
defparam dpb_inst_10.WRITE_MODE0 = 2'b00;
defparam dpb_inst_10.WRITE_MODE1 = 2'b00;
defparam dpb_inst_10.BIT_WIDTH_0 = 1;
defparam dpb_inst_10.BIT_WIDTH_1 = 1;
defparam dpb_inst_10.BLK_SEL_0 = 3'b010;
defparam dpb_inst_10.BLK_SEL_1 = 3'b010;
defparam dpb_inst_10.RESET_MODE = "SYNC";

DPB dpb_inst_11 (
    .DOA({dpb_inst_11_douta_w[14:0],dpb_inst_11_douta[3]}),
    .DOB({dpb_inst_11_doutb_w[14:0],dpb_inst_11_doutb[3]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[3]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[3]})
);

defparam dpb_inst_11.READ_MODE0 = 1'b0;
defparam dpb_inst_11.READ_MODE1 = 1'b0;
defparam dpb_inst_11.WRITE_MODE0 = 2'b00;
defparam dpb_inst_11.WRITE_MODE1 = 2'b00;
defparam dpb_inst_11.BIT_WIDTH_0 = 1;
defparam dpb_inst_11.BIT_WIDTH_1 = 1;
defparam dpb_inst_11.BLK_SEL_0 = 3'b010;
defparam dpb_inst_11.BLK_SEL_1 = 3'b010;
defparam dpb_inst_11.RESET_MODE = "SYNC";

DPB dpb_inst_12 (
    .DOA({dpb_inst_12_douta_w[13:0],dpb_inst_12_douta[1:0]}),
    .DOB({dpb_inst_12_doutb_w[13:0],dpb_inst_12_doutb[1:0]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({ada[15],ada[14],ada[13]}),
    .BLKSELB({adb[15],adb[14],adb[13]}),
    .ADA({ada[12:0],gw_gnd}),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[1:0]}),
    .ADB({adb[12:0],gw_gnd}),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[1:0]})
);

defparam dpb_inst_12.READ_MODE0 = 1'b0;
defparam dpb_inst_12.READ_MODE1 = 1'b0;
defparam dpb_inst_12.WRITE_MODE0 = 2'b00;
defparam dpb_inst_12.WRITE_MODE1 = 2'b00;
defparam dpb_inst_12.BIT_WIDTH_0 = 2;
defparam dpb_inst_12.BIT_WIDTH_1 = 2;
defparam dpb_inst_12.BLK_SEL_0 = 3'b110;
defparam dpb_inst_12.BLK_SEL_1 = 3'b110;
defparam dpb_inst_12.RESET_MODE = "SYNC";

DPB dpb_inst_13 (
    .DOA({dpb_inst_13_douta_w[13:0],dpb_inst_13_douta[3:2]}),
    .DOB({dpb_inst_13_doutb_w[13:0],dpb_inst_13_doutb[3:2]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({ada[15],ada[14],ada[13]}),
    .BLKSELB({adb[15],adb[14],adb[13]}),
    .ADA({ada[12:0],gw_gnd}),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[3:2]}),
    .ADB({adb[12:0],gw_gnd}),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[3:2]})
);

defparam dpb_inst_13.READ_MODE0 = 1'b0;
defparam dpb_inst_13.READ_MODE1 = 1'b0;
defparam dpb_inst_13.WRITE_MODE0 = 2'b00;
defparam dpb_inst_13.WRITE_MODE1 = 2'b00;
defparam dpb_inst_13.BIT_WIDTH_0 = 2;
defparam dpb_inst_13.BIT_WIDTH_1 = 2;
defparam dpb_inst_13.BLK_SEL_0 = 3'b110;
defparam dpb_inst_13.BLK_SEL_1 = 3'b110;
defparam dpb_inst_13.RESET_MODE = "SYNC";

DPB dpb_inst_14 (
    .DOA({dpb_inst_14_douta_w[11:0],dpb_inst_14_douta[3:0]}),
    .DOB({dpb_inst_14_doutb_w[11:0],dpb_inst_14_doutb[3:0]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,gw_gnd,lut_f_0}),
    .BLKSELB({gw_gnd,gw_gnd,lut_f_1}),
    .ADA({ada[11:0],gw_gnd,gw_gnd}),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[3:0]}),
    .ADB({adb[11:0],gw_gnd,gw_gnd}),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[3:0]})
);

defparam dpb_inst_14.READ_MODE0 = 1'b0;
defparam dpb_inst_14.READ_MODE1 = 1'b0;
defparam dpb_inst_14.WRITE_MODE0 = 2'b00;
defparam dpb_inst_14.WRITE_MODE1 = 2'b00;
defparam dpb_inst_14.BIT_WIDTH_0 = 4;
defparam dpb_inst_14.BIT_WIDTH_1 = 4;
defparam dpb_inst_14.BLK_SEL_0 = 3'b001;
defparam dpb_inst_14.BLK_SEL_1 = 3'b001;
defparam dpb_inst_14.RESET_MODE = "SYNC";

DPB dpb_inst_15 (
    .DOA({dpb_inst_15_douta_w[14:0],dpb_inst_15_douta[4]}),
    .DOB({dpb_inst_15_doutb_w[14:0],dpb_inst_15_doutb[4]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[4]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[4]})
);

defparam dpb_inst_15.READ_MODE0 = 1'b0;
defparam dpb_inst_15.READ_MODE1 = 1'b0;
defparam dpb_inst_15.WRITE_MODE0 = 2'b00;
defparam dpb_inst_15.WRITE_MODE1 = 2'b00;
defparam dpb_inst_15.BIT_WIDTH_0 = 1;
defparam dpb_inst_15.BIT_WIDTH_1 = 1;
defparam dpb_inst_15.BLK_SEL_0 = 3'b000;
defparam dpb_inst_15.BLK_SEL_1 = 3'b000;
defparam dpb_inst_15.RESET_MODE = "SYNC";

DPB dpb_inst_16 (
    .DOA({dpb_inst_16_douta_w[14:0],dpb_inst_16_douta[4]}),
    .DOB({dpb_inst_16_doutb_w[14:0],dpb_inst_16_doutb[4]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[4]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[4]})
);

defparam dpb_inst_16.READ_MODE0 = 1'b0;
defparam dpb_inst_16.READ_MODE1 = 1'b0;
defparam dpb_inst_16.WRITE_MODE0 = 2'b00;
defparam dpb_inst_16.WRITE_MODE1 = 2'b00;
defparam dpb_inst_16.BIT_WIDTH_0 = 1;
defparam dpb_inst_16.BIT_WIDTH_1 = 1;
defparam dpb_inst_16.BLK_SEL_0 = 3'b001;
defparam dpb_inst_16.BLK_SEL_1 = 3'b001;
defparam dpb_inst_16.RESET_MODE = "SYNC";

DPB dpb_inst_17 (
    .DOA({dpb_inst_17_douta_w[14:0],dpb_inst_17_douta[5]}),
    .DOB({dpb_inst_17_doutb_w[14:0],dpb_inst_17_doutb[5]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[5]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[5]})
);

defparam dpb_inst_17.READ_MODE0 = 1'b0;
defparam dpb_inst_17.READ_MODE1 = 1'b0;
defparam dpb_inst_17.WRITE_MODE0 = 2'b00;
defparam dpb_inst_17.WRITE_MODE1 = 2'b00;
defparam dpb_inst_17.BIT_WIDTH_0 = 1;
defparam dpb_inst_17.BIT_WIDTH_1 = 1;
defparam dpb_inst_17.BLK_SEL_0 = 3'b000;
defparam dpb_inst_17.BLK_SEL_1 = 3'b000;
defparam dpb_inst_17.RESET_MODE = "SYNC";

DPB dpb_inst_18 (
    .DOA({dpb_inst_18_douta_w[14:0],dpb_inst_18_douta[5]}),
    .DOB({dpb_inst_18_doutb_w[14:0],dpb_inst_18_doutb[5]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[5]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[5]})
);

defparam dpb_inst_18.READ_MODE0 = 1'b0;
defparam dpb_inst_18.READ_MODE1 = 1'b0;
defparam dpb_inst_18.WRITE_MODE0 = 2'b00;
defparam dpb_inst_18.WRITE_MODE1 = 2'b00;
defparam dpb_inst_18.BIT_WIDTH_0 = 1;
defparam dpb_inst_18.BIT_WIDTH_1 = 1;
defparam dpb_inst_18.BLK_SEL_0 = 3'b001;
defparam dpb_inst_18.BLK_SEL_1 = 3'b001;
defparam dpb_inst_18.RESET_MODE = "SYNC";

DPB dpb_inst_19 (
    .DOA({dpb_inst_19_douta_w[14:0],dpb_inst_19_douta[6]}),
    .DOB({dpb_inst_19_doutb_w[14:0],dpb_inst_19_doutb[6]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[6]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[6]})
);

defparam dpb_inst_19.READ_MODE0 = 1'b0;
defparam dpb_inst_19.READ_MODE1 = 1'b0;
defparam dpb_inst_19.WRITE_MODE0 = 2'b00;
defparam dpb_inst_19.WRITE_MODE1 = 2'b00;
defparam dpb_inst_19.BIT_WIDTH_0 = 1;
defparam dpb_inst_19.BIT_WIDTH_1 = 1;
defparam dpb_inst_19.BLK_SEL_0 = 3'b000;
defparam dpb_inst_19.BLK_SEL_1 = 3'b000;
defparam dpb_inst_19.RESET_MODE = "SYNC";

DPB dpb_inst_20 (
    .DOA({dpb_inst_20_douta_w[14:0],dpb_inst_20_douta[6]}),
    .DOB({dpb_inst_20_doutb_w[14:0],dpb_inst_20_doutb[6]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[6]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[6]})
);

defparam dpb_inst_20.READ_MODE0 = 1'b0;
defparam dpb_inst_20.READ_MODE1 = 1'b0;
defparam dpb_inst_20.WRITE_MODE0 = 2'b00;
defparam dpb_inst_20.WRITE_MODE1 = 2'b00;
defparam dpb_inst_20.BIT_WIDTH_0 = 1;
defparam dpb_inst_20.BIT_WIDTH_1 = 1;
defparam dpb_inst_20.BLK_SEL_0 = 3'b001;
defparam dpb_inst_20.BLK_SEL_1 = 3'b001;
defparam dpb_inst_20.RESET_MODE = "SYNC";

DPB dpb_inst_21 (
    .DOA({dpb_inst_21_douta_w[14:0],dpb_inst_21_douta[7]}),
    .DOB({dpb_inst_21_doutb_w[14:0],dpb_inst_21_doutb[7]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[7]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[7]})
);

defparam dpb_inst_21.READ_MODE0 = 1'b0;
defparam dpb_inst_21.READ_MODE1 = 1'b0;
defparam dpb_inst_21.WRITE_MODE0 = 2'b00;
defparam dpb_inst_21.WRITE_MODE1 = 2'b00;
defparam dpb_inst_21.BIT_WIDTH_0 = 1;
defparam dpb_inst_21.BIT_WIDTH_1 = 1;
defparam dpb_inst_21.BLK_SEL_0 = 3'b000;
defparam dpb_inst_21.BLK_SEL_1 = 3'b000;
defparam dpb_inst_21.RESET_MODE = "SYNC";

DPB dpb_inst_22 (
    .DOA({dpb_inst_22_douta_w[14:0],dpb_inst_22_douta[7]}),
    .DOB({dpb_inst_22_doutb_w[14:0],dpb_inst_22_doutb[7]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[7]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[7]})
);

defparam dpb_inst_22.READ_MODE0 = 1'b0;
defparam dpb_inst_22.READ_MODE1 = 1'b0;
defparam dpb_inst_22.WRITE_MODE0 = 2'b00;
defparam dpb_inst_22.WRITE_MODE1 = 2'b00;
defparam dpb_inst_22.BIT_WIDTH_0 = 1;
defparam dpb_inst_22.BIT_WIDTH_1 = 1;
defparam dpb_inst_22.BLK_SEL_0 = 3'b001;
defparam dpb_inst_22.BLK_SEL_1 = 3'b001;
defparam dpb_inst_22.RESET_MODE = "SYNC";

DPB dpb_inst_23 (
    .DOA({dpb_inst_23_douta_w[14:0],dpb_inst_23_douta[4]}),
    .DOB({dpb_inst_23_doutb_w[14:0],dpb_inst_23_doutb[4]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[4]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[4]})
);

defparam dpb_inst_23.READ_MODE0 = 1'b0;
defparam dpb_inst_23.READ_MODE1 = 1'b0;
defparam dpb_inst_23.WRITE_MODE0 = 2'b00;
defparam dpb_inst_23.WRITE_MODE1 = 2'b00;
defparam dpb_inst_23.BIT_WIDTH_0 = 1;
defparam dpb_inst_23.BIT_WIDTH_1 = 1;
defparam dpb_inst_23.BLK_SEL_0 = 3'b010;
defparam dpb_inst_23.BLK_SEL_1 = 3'b010;
defparam dpb_inst_23.RESET_MODE = "SYNC";

DPB dpb_inst_24 (
    .DOA({dpb_inst_24_douta_w[14:0],dpb_inst_24_douta[5]}),
    .DOB({dpb_inst_24_doutb_w[14:0],dpb_inst_24_doutb[5]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[5]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[5]})
);

defparam dpb_inst_24.READ_MODE0 = 1'b0;
defparam dpb_inst_24.READ_MODE1 = 1'b0;
defparam dpb_inst_24.WRITE_MODE0 = 2'b00;
defparam dpb_inst_24.WRITE_MODE1 = 2'b00;
defparam dpb_inst_24.BIT_WIDTH_0 = 1;
defparam dpb_inst_24.BIT_WIDTH_1 = 1;
defparam dpb_inst_24.BLK_SEL_0 = 3'b010;
defparam dpb_inst_24.BLK_SEL_1 = 3'b010;
defparam dpb_inst_24.RESET_MODE = "SYNC";

DPB dpb_inst_25 (
    .DOA({dpb_inst_25_douta_w[14:0],dpb_inst_25_douta[6]}),
    .DOB({dpb_inst_25_doutb_w[14:0],dpb_inst_25_doutb[6]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[6]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[6]})
);

defparam dpb_inst_25.READ_MODE0 = 1'b0;
defparam dpb_inst_25.READ_MODE1 = 1'b0;
defparam dpb_inst_25.WRITE_MODE0 = 2'b00;
defparam dpb_inst_25.WRITE_MODE1 = 2'b00;
defparam dpb_inst_25.BIT_WIDTH_0 = 1;
defparam dpb_inst_25.BIT_WIDTH_1 = 1;
defparam dpb_inst_25.BLK_SEL_0 = 3'b010;
defparam dpb_inst_25.BLK_SEL_1 = 3'b010;
defparam dpb_inst_25.RESET_MODE = "SYNC";

DPB dpb_inst_26 (
    .DOA({dpb_inst_26_douta_w[14:0],dpb_inst_26_douta[7]}),
    .DOB({dpb_inst_26_doutb_w[14:0],dpb_inst_26_doutb[7]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[15],adb[14]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[7]}),
    .ADB(adb[13:0]),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[7]})
);

defparam dpb_inst_26.READ_MODE0 = 1'b0;
defparam dpb_inst_26.READ_MODE1 = 1'b0;
defparam dpb_inst_26.WRITE_MODE0 = 2'b00;
defparam dpb_inst_26.WRITE_MODE1 = 2'b00;
defparam dpb_inst_26.BIT_WIDTH_0 = 1;
defparam dpb_inst_26.BIT_WIDTH_1 = 1;
defparam dpb_inst_26.BLK_SEL_0 = 3'b010;
defparam dpb_inst_26.BLK_SEL_1 = 3'b010;
defparam dpb_inst_26.RESET_MODE = "SYNC";

DPB dpb_inst_27 (
    .DOA({dpb_inst_27_douta_w[13:0],dpb_inst_27_douta[5:4]}),
    .DOB({dpb_inst_27_doutb_w[13:0],dpb_inst_27_doutb[5:4]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({ada[15],ada[14],ada[13]}),
    .BLKSELB({adb[15],adb[14],adb[13]}),
    .ADA({ada[12:0],gw_gnd}),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[5:4]}),
    .ADB({adb[12:0],gw_gnd}),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[5:4]})
);

defparam dpb_inst_27.READ_MODE0 = 1'b0;
defparam dpb_inst_27.READ_MODE1 = 1'b0;
defparam dpb_inst_27.WRITE_MODE0 = 2'b00;
defparam dpb_inst_27.WRITE_MODE1 = 2'b00;
defparam dpb_inst_27.BIT_WIDTH_0 = 2;
defparam dpb_inst_27.BIT_WIDTH_1 = 2;
defparam dpb_inst_27.BLK_SEL_0 = 3'b110;
defparam dpb_inst_27.BLK_SEL_1 = 3'b110;
defparam dpb_inst_27.RESET_MODE = "SYNC";

DPB dpb_inst_28 (
    .DOA({dpb_inst_28_douta_w[13:0],dpb_inst_28_douta[7:6]}),
    .DOB({dpb_inst_28_doutb_w[13:0],dpb_inst_28_doutb[7:6]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({ada[15],ada[14],ada[13]}),
    .BLKSELB({adb[15],adb[14],adb[13]}),
    .ADA({ada[12:0],gw_gnd}),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[7:6]}),
    .ADB({adb[12:0],gw_gnd}),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[7:6]})
);

defparam dpb_inst_28.READ_MODE0 = 1'b0;
defparam dpb_inst_28.READ_MODE1 = 1'b0;
defparam dpb_inst_28.WRITE_MODE0 = 2'b00;
defparam dpb_inst_28.WRITE_MODE1 = 2'b00;
defparam dpb_inst_28.BIT_WIDTH_0 = 2;
defparam dpb_inst_28.BIT_WIDTH_1 = 2;
defparam dpb_inst_28.BLK_SEL_0 = 3'b110;
defparam dpb_inst_28.BLK_SEL_1 = 3'b110;
defparam dpb_inst_28.RESET_MODE = "SYNC";

DPB dpb_inst_29 (
    .DOA({dpb_inst_29_douta_w[11:0],dpb_inst_29_douta[7:4]}),
    .DOB({dpb_inst_29_doutb_w[11:0],dpb_inst_29_doutb[7:4]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,gw_gnd,lut_f_0}),
    .BLKSELB({gw_gnd,gw_gnd,lut_f_1}),
    .ADA({ada[11:0],gw_gnd,gw_gnd}),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[7:4]}),
    .ADB({adb[11:0],gw_gnd,gw_gnd}),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[7:4]})
);

defparam dpb_inst_29.READ_MODE0 = 1'b0;
defparam dpb_inst_29.READ_MODE1 = 1'b0;
defparam dpb_inst_29.WRITE_MODE0 = 2'b00;
defparam dpb_inst_29.WRITE_MODE1 = 2'b00;
defparam dpb_inst_29.BIT_WIDTH_0 = 4;
defparam dpb_inst_29.BIT_WIDTH_1 = 4;
defparam dpb_inst_29.BLK_SEL_0 = 3'b001;
defparam dpb_inst_29.BLK_SEL_1 = 3'b001;
defparam dpb_inst_29.RESET_MODE = "SYNC";

DFFRE dff_inst_0 (
  .Q(dff_q_0),
  .D(ada[15]),
  .CLK(clka),
  .CE(cea_w),
  .RESET(gw_gnd)
);
DFFRE dff_inst_1 (
  .Q(dff_q_1),
  .D(ada[14]),
  .CLK(clka),
  .CE(cea_w),
  .RESET(gw_gnd)
);
DFFRE dff_inst_2 (
  .Q(dff_q_2),
  .D(ada[13]),
  .CLK(clka),
  .CE(cea_w),
  .RESET(gw_gnd)
);
DFFRE dff_inst_3 (
  .Q(dff_q_3),
  .D(adb[15]),
  .CLK(clkb),
  .CE(ceb_w),
  .RESET(gw_gnd)
);
DFFRE dff_inst_4 (
  .Q(dff_q_4),
  .D(adb[14]),
  .CLK(clkb),
  .CE(ceb_w),
  .RESET(gw_gnd)
);
DFFRE dff_inst_5 (
  .Q(dff_q_5),
  .D(adb[13]),
  .CLK(clkb),
  .CE(ceb_w),
  .RESET(gw_gnd)
);
MUX2 mux_inst_8 (
  .O(mux_o_8),
  .I0(dpb_inst_12_douta[0]),
  .I1(dpb_inst_14_douta[0]),
  .S0(dff_q_2)
);
MUX2 mux_inst_9 (
  .O(mux_o_9),
  .I0(dpb_inst_0_douta[0]),
  .I1(dpb_inst_1_douta[0]),
  .S0(dff_q_1)
);
MUX2 mux_inst_10 (
  .O(mux_o_10),
  .I0(dpb_inst_8_douta[0]),
  .I1(mux_o_8),
  .S0(dff_q_1)
);
MUX2 mux_inst_11 (
  .O(douta[0]),
  .I0(mux_o_9),
  .I1(mux_o_10),
  .S0(dff_q_0)
);
MUX2 mux_inst_20 (
  .O(mux_o_20),
  .I0(dpb_inst_12_douta[1]),
  .I1(dpb_inst_14_douta[1]),
  .S0(dff_q_2)
);
MUX2 mux_inst_21 (
  .O(mux_o_21),
  .I0(dpb_inst_2_douta[1]),
  .I1(dpb_inst_3_douta[1]),
  .S0(dff_q_1)
);
MUX2 mux_inst_22 (
  .O(mux_o_22),
  .I0(dpb_inst_9_douta[1]),
  .I1(mux_o_20),
  .S0(dff_q_1)
);
MUX2 mux_inst_23 (
  .O(douta[1]),
  .I0(mux_o_21),
  .I1(mux_o_22),
  .S0(dff_q_0)
);
MUX2 mux_inst_32 (
  .O(mux_o_32),
  .I0(dpb_inst_13_douta[2]),
  .I1(dpb_inst_14_douta[2]),
  .S0(dff_q_2)
);
MUX2 mux_inst_33 (
  .O(mux_o_33),
  .I0(dpb_inst_4_douta[2]),
  .I1(dpb_inst_5_douta[2]),
  .S0(dff_q_1)
);
MUX2 mux_inst_34 (
  .O(mux_o_34),
  .I0(dpb_inst_10_douta[2]),
  .I1(mux_o_32),
  .S0(dff_q_1)
);
MUX2 mux_inst_35 (
  .O(douta[2]),
  .I0(mux_o_33),
  .I1(mux_o_34),
  .S0(dff_q_0)
);
MUX2 mux_inst_44 (
  .O(mux_o_44),
  .I0(dpb_inst_13_douta[3]),
  .I1(dpb_inst_14_douta[3]),
  .S0(dff_q_2)
);
MUX2 mux_inst_45 (
  .O(mux_o_45),
  .I0(dpb_inst_6_douta[3]),
  .I1(dpb_inst_7_douta[3]),
  .S0(dff_q_1)
);
MUX2 mux_inst_46 (
  .O(mux_o_46),
  .I0(dpb_inst_11_douta[3]),
  .I1(mux_o_44),
  .S0(dff_q_1)
);
MUX2 mux_inst_47 (
  .O(douta[3]),
  .I0(mux_o_45),
  .I1(mux_o_46),
  .S0(dff_q_0)
);
MUX2 mux_inst_56 (
  .O(mux_o_56),
  .I0(dpb_inst_27_douta[4]),
  .I1(dpb_inst_29_douta[4]),
  .S0(dff_q_2)
);
MUX2 mux_inst_57 (
  .O(mux_o_57),
  .I0(dpb_inst_15_douta[4]),
  .I1(dpb_inst_16_douta[4]),
  .S0(dff_q_1)
);
MUX2 mux_inst_58 (
  .O(mux_o_58),
  .I0(dpb_inst_23_douta[4]),
  .I1(mux_o_56),
  .S0(dff_q_1)
);
MUX2 mux_inst_59 (
  .O(douta[4]),
  .I0(mux_o_57),
  .I1(mux_o_58),
  .S0(dff_q_0)
);
MUX2 mux_inst_68 (
  .O(mux_o_68),
  .I0(dpb_inst_27_douta[5]),
  .I1(dpb_inst_29_douta[5]),
  .S0(dff_q_2)
);
MUX2 mux_inst_69 (
  .O(mux_o_69),
  .I0(dpb_inst_17_douta[5]),
  .I1(dpb_inst_18_douta[5]),
  .S0(dff_q_1)
);
MUX2 mux_inst_70 (
  .O(mux_o_70),
  .I0(dpb_inst_24_douta[5]),
  .I1(mux_o_68),
  .S0(dff_q_1)
);
MUX2 mux_inst_71 (
  .O(douta[5]),
  .I0(mux_o_69),
  .I1(mux_o_70),
  .S0(dff_q_0)
);
MUX2 mux_inst_80 (
  .O(mux_o_80),
  .I0(dpb_inst_28_douta[6]),
  .I1(dpb_inst_29_douta[6]),
  .S0(dff_q_2)
);
MUX2 mux_inst_81 (
  .O(mux_o_81),
  .I0(dpb_inst_19_douta[6]),
  .I1(dpb_inst_20_douta[6]),
  .S0(dff_q_1)
);
MUX2 mux_inst_82 (
  .O(mux_o_82),
  .I0(dpb_inst_25_douta[6]),
  .I1(mux_o_80),
  .S0(dff_q_1)
);
MUX2 mux_inst_83 (
  .O(douta[6]),
  .I0(mux_o_81),
  .I1(mux_o_82),
  .S0(dff_q_0)
);
MUX2 mux_inst_92 (
  .O(mux_o_92),
  .I0(dpb_inst_28_douta[7]),
  .I1(dpb_inst_29_douta[7]),
  .S0(dff_q_2)
);
MUX2 mux_inst_93 (
  .O(mux_o_93),
  .I0(dpb_inst_21_douta[7]),
  .I1(dpb_inst_22_douta[7]),
  .S0(dff_q_1)
);
MUX2 mux_inst_94 (
  .O(mux_o_94),
  .I0(dpb_inst_26_douta[7]),
  .I1(mux_o_92),
  .S0(dff_q_1)
);
MUX2 mux_inst_95 (
  .O(douta[7]),
  .I0(mux_o_93),
  .I1(mux_o_94),
  .S0(dff_q_0)
);
MUX2 mux_inst_104 (
  .O(mux_o_104),
  .I0(dpb_inst_12_doutb[0]),
  .I1(dpb_inst_14_doutb[0]),
  .S0(dff_q_5)
);
MUX2 mux_inst_105 (
  .O(mux_o_105),
  .I0(dpb_inst_0_doutb[0]),
  .I1(dpb_inst_1_doutb[0]),
  .S0(dff_q_4)
);
MUX2 mux_inst_106 (
  .O(mux_o_106),
  .I0(dpb_inst_8_doutb[0]),
  .I1(mux_o_104),
  .S0(dff_q_4)
);
MUX2 mux_inst_107 (
  .O(doutb[0]),
  .I0(mux_o_105),
  .I1(mux_o_106),
  .S0(dff_q_3)
);
MUX2 mux_inst_116 (
  .O(mux_o_116),
  .I0(dpb_inst_12_doutb[1]),
  .I1(dpb_inst_14_doutb[1]),
  .S0(dff_q_5)
);
MUX2 mux_inst_117 (
  .O(mux_o_117),
  .I0(dpb_inst_2_doutb[1]),
  .I1(dpb_inst_3_doutb[1]),
  .S0(dff_q_4)
);
MUX2 mux_inst_118 (
  .O(mux_o_118),
  .I0(dpb_inst_9_doutb[1]),
  .I1(mux_o_116),
  .S0(dff_q_4)
);
MUX2 mux_inst_119 (
  .O(doutb[1]),
  .I0(mux_o_117),
  .I1(mux_o_118),
  .S0(dff_q_3)
);
MUX2 mux_inst_128 (
  .O(mux_o_128),
  .I0(dpb_inst_13_doutb[2]),
  .I1(dpb_inst_14_doutb[2]),
  .S0(dff_q_5)
);
MUX2 mux_inst_129 (
  .O(mux_o_129),
  .I0(dpb_inst_4_doutb[2]),
  .I1(dpb_inst_5_doutb[2]),
  .S0(dff_q_4)
);
MUX2 mux_inst_130 (
  .O(mux_o_130),
  .I0(dpb_inst_10_doutb[2]),
  .I1(mux_o_128),
  .S0(dff_q_4)
);
MUX2 mux_inst_131 (
  .O(doutb[2]),
  .I0(mux_o_129),
  .I1(mux_o_130),
  .S0(dff_q_3)
);
MUX2 mux_inst_140 (
  .O(mux_o_140),
  .I0(dpb_inst_13_doutb[3]),
  .I1(dpb_inst_14_doutb[3]),
  .S0(dff_q_5)
);
MUX2 mux_inst_141 (
  .O(mux_o_141),
  .I0(dpb_inst_6_doutb[3]),
  .I1(dpb_inst_7_doutb[3]),
  .S0(dff_q_4)
);
MUX2 mux_inst_142 (
  .O(mux_o_142),
  .I0(dpb_inst_11_doutb[3]),
  .I1(mux_o_140),
  .S0(dff_q_4)
);
MUX2 mux_inst_143 (
  .O(doutb[3]),
  .I0(mux_o_141),
  .I1(mux_o_142),
  .S0(dff_q_3)
);
MUX2 mux_inst_152 (
  .O(mux_o_152),
  .I0(dpb_inst_27_doutb[4]),
  .I1(dpb_inst_29_doutb[4]),
  .S0(dff_q_5)
);
MUX2 mux_inst_153 (
  .O(mux_o_153),
  .I0(dpb_inst_15_doutb[4]),
  .I1(dpb_inst_16_doutb[4]),
  .S0(dff_q_4)
);
MUX2 mux_inst_154 (
  .O(mux_o_154),
  .I0(dpb_inst_23_doutb[4]),
  .I1(mux_o_152),
  .S0(dff_q_4)
);
MUX2 mux_inst_155 (
  .O(doutb[4]),
  .I0(mux_o_153),
  .I1(mux_o_154),
  .S0(dff_q_3)
);
MUX2 mux_inst_164 (
  .O(mux_o_164),
  .I0(dpb_inst_27_doutb[5]),
  .I1(dpb_inst_29_doutb[5]),
  .S0(dff_q_5)
);
MUX2 mux_inst_165 (
  .O(mux_o_165),
  .I0(dpb_inst_17_doutb[5]),
  .I1(dpb_inst_18_doutb[5]),
  .S0(dff_q_4)
);
MUX2 mux_inst_166 (
  .O(mux_o_166),
  .I0(dpb_inst_24_doutb[5]),
  .I1(mux_o_164),
  .S0(dff_q_4)
);
MUX2 mux_inst_167 (
  .O(doutb[5]),
  .I0(mux_o_165),
  .I1(mux_o_166),
  .S0(dff_q_3)
);
MUX2 mux_inst_176 (
  .O(mux_o_176),
  .I0(dpb_inst_28_doutb[6]),
  .I1(dpb_inst_29_doutb[6]),
  .S0(dff_q_5)
);
MUX2 mux_inst_177 (
  .O(mux_o_177),
  .I0(dpb_inst_19_doutb[6]),
  .I1(dpb_inst_20_doutb[6]),
  .S0(dff_q_4)
);
MUX2 mux_inst_178 (
  .O(mux_o_178),
  .I0(dpb_inst_25_doutb[6]),
  .I1(mux_o_176),
  .S0(dff_q_4)
);
MUX2 mux_inst_179 (
  .O(doutb[6]),
  .I0(mux_o_177),
  .I1(mux_o_178),
  .S0(dff_q_3)
);
MUX2 mux_inst_188 (
  .O(mux_o_188),
  .I0(dpb_inst_28_doutb[7]),
  .I1(dpb_inst_29_doutb[7]),
  .S0(dff_q_5)
);
MUX2 mux_inst_189 (
  .O(mux_o_189),
  .I0(dpb_inst_21_doutb[7]),
  .I1(dpb_inst_22_doutb[7]),
  .S0(dff_q_4)
);
MUX2 mux_inst_190 (
  .O(mux_o_190),
  .I0(dpb_inst_26_doutb[7]),
  .I1(mux_o_188),
  .S0(dff_q_4)
);
MUX2 mux_inst_191 (
  .O(doutb[7]),
  .I0(mux_o_189),
  .I1(mux_o_190),
  .S0(dff_q_3)
);
endmodule //cflea_main_men
