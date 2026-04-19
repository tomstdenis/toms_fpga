//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//Tool Version: V1.9.11.03 Education
//Part Number: GW5A-LV25MG121NC1/I0
//Device: GW5A-25
//Device Version: A
//Created Time: Sun Apr 19 12:29:56 2026
`default_nettype wire
module main_memory (douta, doutb, clka, ocea, cea, reseta, wrea, clkb, oceb, ceb, resetb, wreb, ada, dina, adb, dinb);

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
wire [4:4] dpb_inst_8_douta;
wire [14:0] dpb_inst_8_doutb_w;
wire [4:4] dpb_inst_8_doutb;
wire [14:0] dpb_inst_9_douta_w;
wire [4:4] dpb_inst_9_douta;
wire [14:0] dpb_inst_9_doutb_w;
wire [4:4] dpb_inst_9_doutb;
wire [14:0] dpb_inst_10_douta_w;
wire [5:5] dpb_inst_10_douta;
wire [14:0] dpb_inst_10_doutb_w;
wire [5:5] dpb_inst_10_doutb;
wire [14:0] dpb_inst_11_douta_w;
wire [5:5] dpb_inst_11_douta;
wire [14:0] dpb_inst_11_doutb_w;
wire [5:5] dpb_inst_11_doutb;
wire [14:0] dpb_inst_12_douta_w;
wire [6:6] dpb_inst_12_douta;
wire [14:0] dpb_inst_12_doutb_w;
wire [6:6] dpb_inst_12_doutb;
wire [14:0] dpb_inst_13_douta_w;
wire [6:6] dpb_inst_13_douta;
wire [14:0] dpb_inst_13_doutb_w;
wire [6:6] dpb_inst_13_doutb;
wire [14:0] dpb_inst_14_douta_w;
wire [7:7] dpb_inst_14_douta;
wire [14:0] dpb_inst_14_doutb_w;
wire [7:7] dpb_inst_14_doutb;
wire [14:0] dpb_inst_15_douta_w;
wire [7:7] dpb_inst_15_douta;
wire [14:0] dpb_inst_15_doutb_w;
wire [7:7] dpb_inst_15_doutb;
wire [14:0] dpb_inst_16_douta_w;
wire [0:0] dpb_inst_16_douta;
wire [14:0] dpb_inst_16_doutb_w;
wire [0:0] dpb_inst_16_doutb;
wire [14:0] dpb_inst_17_douta_w;
wire [1:1] dpb_inst_17_douta;
wire [14:0] dpb_inst_17_doutb_w;
wire [1:1] dpb_inst_17_doutb;
wire [14:0] dpb_inst_18_douta_w;
wire [2:2] dpb_inst_18_douta;
wire [14:0] dpb_inst_18_doutb_w;
wire [2:2] dpb_inst_18_doutb;
wire [14:0] dpb_inst_19_douta_w;
wire [3:3] dpb_inst_19_douta;
wire [14:0] dpb_inst_19_doutb_w;
wire [3:3] dpb_inst_19_doutb;
wire [14:0] dpb_inst_20_douta_w;
wire [4:4] dpb_inst_20_douta;
wire [14:0] dpb_inst_20_doutb_w;
wire [4:4] dpb_inst_20_doutb;
wire [14:0] dpb_inst_21_douta_w;
wire [5:5] dpb_inst_21_douta;
wire [14:0] dpb_inst_21_doutb_w;
wire [5:5] dpb_inst_21_doutb;
wire [14:0] dpb_inst_22_douta_w;
wire [6:6] dpb_inst_22_douta;
wire [14:0] dpb_inst_22_doutb_w;
wire [6:6] dpb_inst_22_doutb;
wire [14:0] dpb_inst_23_douta_w;
wire [7:7] dpb_inst_23_douta;
wire [14:0] dpb_inst_23_doutb_w;
wire [7:7] dpb_inst_23_doutb;
wire [13:0] dpb_inst_24_douta_w;
wire [1:0] dpb_inst_24_douta;
wire [13:0] dpb_inst_24_doutb_w;
wire [1:0] dpb_inst_24_doutb;
wire [13:0] dpb_inst_25_douta_w;
wire [3:2] dpb_inst_25_douta;
wire [13:0] dpb_inst_25_doutb_w;
wire [3:2] dpb_inst_25_doutb;
wire [13:0] dpb_inst_26_douta_w;
wire [5:4] dpb_inst_26_douta;
wire [13:0] dpb_inst_26_doutb_w;
wire [5:4] dpb_inst_26_doutb;
wire [13:0] dpb_inst_27_douta_w;
wire [7:6] dpb_inst_27_douta;
wire [13:0] dpb_inst_27_doutb_w;
wire [7:6] dpb_inst_27_doutb;
wire [7:0] dpb_inst_28_douta_w;
wire [7:0] dpb_inst_28_douta;
wire [7:0] dpb_inst_28_doutb_w;
wire [7:0] dpb_inst_28_doutb;
wire dff_q_0;
wire dff_q_1;
wire dff_q_2;
wire dff_q_3;
wire dff_q_4;
wire dff_q_5;
wire mux_o_13;
wire mux_o_14;
wire mux_o_15;
wire mux_o_30;
wire mux_o_31;
wire mux_o_32;
wire mux_o_47;
wire mux_o_48;
wire mux_o_49;
wire mux_o_64;
wire mux_o_65;
wire mux_o_66;
wire mux_o_81;
wire mux_o_82;
wire mux_o_83;
wire mux_o_98;
wire mux_o_99;
wire mux_o_100;
wire mux_o_115;
wire mux_o_116;
wire mux_o_117;
wire mux_o_132;
wire mux_o_133;
wire mux_o_134;
wire mux_o_149;
wire mux_o_150;
wire mux_o_151;
wire mux_o_166;
wire mux_o_167;
wire mux_o_168;
wire mux_o_183;
wire mux_o_184;
wire mux_o_185;
wire mux_o_200;
wire mux_o_201;
wire mux_o_202;
wire mux_o_217;
wire mux_o_218;
wire mux_o_219;
wire mux_o_234;
wire mux_o_235;
wire mux_o_236;
wire mux_o_251;
wire mux_o_252;
wire mux_o_253;
wire mux_o_268;
wire mux_o_269;
wire mux_o_270;
wire cea_w;
wire ceb_w;
wire gw_gnd;

assign cea_w = ~wrea & cea;
assign ceb_w = ~wreb & ceb;
assign gw_gnd = 1'b0;

LUT5 lut_inst_0 (
  .F(lut_f_0),
  .I0(ada[11]),
  .I1(ada[12]),
  .I2(ada[13]),
  .I3(ada[14]),
  .I4(ada[15])
);
defparam lut_inst_0.INIT = 32'h10000000;
LUT5 lut_inst_1 (
  .F(lut_f_1),
  .I0(adb[11]),
  .I1(adb[12]),
  .I2(adb[13]),
  .I3(adb[14]),
  .I4(adb[15])
);
defparam lut_inst_1.INIT = 32'h10000000;
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
    .DOA({dpb_inst_8_douta_w[14:0],dpb_inst_8_douta[4]}),
    .DOB({dpb_inst_8_doutb_w[14:0],dpb_inst_8_doutb[4]}),
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

defparam dpb_inst_8.READ_MODE0 = 1'b0;
defparam dpb_inst_8.READ_MODE1 = 1'b0;
defparam dpb_inst_8.WRITE_MODE0 = 2'b00;
defparam dpb_inst_8.WRITE_MODE1 = 2'b00;
defparam dpb_inst_8.BIT_WIDTH_0 = 1;
defparam dpb_inst_8.BIT_WIDTH_1 = 1;
defparam dpb_inst_8.BLK_SEL_0 = 3'b000;
defparam dpb_inst_8.BLK_SEL_1 = 3'b000;
defparam dpb_inst_8.RESET_MODE = "SYNC";

DPB dpb_inst_9 (
    .DOA({dpb_inst_9_douta_w[14:0],dpb_inst_9_douta[4]}),
    .DOB({dpb_inst_9_doutb_w[14:0],dpb_inst_9_doutb[4]}),
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

defparam dpb_inst_9.READ_MODE0 = 1'b0;
defparam dpb_inst_9.READ_MODE1 = 1'b0;
defparam dpb_inst_9.WRITE_MODE0 = 2'b00;
defparam dpb_inst_9.WRITE_MODE1 = 2'b00;
defparam dpb_inst_9.BIT_WIDTH_0 = 1;
defparam dpb_inst_9.BIT_WIDTH_1 = 1;
defparam dpb_inst_9.BLK_SEL_0 = 3'b001;
defparam dpb_inst_9.BLK_SEL_1 = 3'b001;
defparam dpb_inst_9.RESET_MODE = "SYNC";

DPB dpb_inst_10 (
    .DOA({dpb_inst_10_douta_w[14:0],dpb_inst_10_douta[5]}),
    .DOB({dpb_inst_10_doutb_w[14:0],dpb_inst_10_doutb[5]}),
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

defparam dpb_inst_10.READ_MODE0 = 1'b0;
defparam dpb_inst_10.READ_MODE1 = 1'b0;
defparam dpb_inst_10.WRITE_MODE0 = 2'b00;
defparam dpb_inst_10.WRITE_MODE1 = 2'b00;
defparam dpb_inst_10.BIT_WIDTH_0 = 1;
defparam dpb_inst_10.BIT_WIDTH_1 = 1;
defparam dpb_inst_10.BLK_SEL_0 = 3'b000;
defparam dpb_inst_10.BLK_SEL_1 = 3'b000;
defparam dpb_inst_10.RESET_MODE = "SYNC";

DPB dpb_inst_11 (
    .DOA({dpb_inst_11_douta_w[14:0],dpb_inst_11_douta[5]}),
    .DOB({dpb_inst_11_doutb_w[14:0],dpb_inst_11_doutb[5]}),
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

defparam dpb_inst_11.READ_MODE0 = 1'b0;
defparam dpb_inst_11.READ_MODE1 = 1'b0;
defparam dpb_inst_11.WRITE_MODE0 = 2'b00;
defparam dpb_inst_11.WRITE_MODE1 = 2'b00;
defparam dpb_inst_11.BIT_WIDTH_0 = 1;
defparam dpb_inst_11.BIT_WIDTH_1 = 1;
defparam dpb_inst_11.BLK_SEL_0 = 3'b001;
defparam dpb_inst_11.BLK_SEL_1 = 3'b001;
defparam dpb_inst_11.RESET_MODE = "SYNC";

DPB dpb_inst_12 (
    .DOA({dpb_inst_12_douta_w[14:0],dpb_inst_12_douta[6]}),
    .DOB({dpb_inst_12_doutb_w[14:0],dpb_inst_12_doutb[6]}),
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

defparam dpb_inst_12.READ_MODE0 = 1'b0;
defparam dpb_inst_12.READ_MODE1 = 1'b0;
defparam dpb_inst_12.WRITE_MODE0 = 2'b00;
defparam dpb_inst_12.WRITE_MODE1 = 2'b00;
defparam dpb_inst_12.BIT_WIDTH_0 = 1;
defparam dpb_inst_12.BIT_WIDTH_1 = 1;
defparam dpb_inst_12.BLK_SEL_0 = 3'b000;
defparam dpb_inst_12.BLK_SEL_1 = 3'b000;
defparam dpb_inst_12.RESET_MODE = "SYNC";

DPB dpb_inst_13 (
    .DOA({dpb_inst_13_douta_w[14:0],dpb_inst_13_douta[6]}),
    .DOB({dpb_inst_13_doutb_w[14:0],dpb_inst_13_doutb[6]}),
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

defparam dpb_inst_13.READ_MODE0 = 1'b0;
defparam dpb_inst_13.READ_MODE1 = 1'b0;
defparam dpb_inst_13.WRITE_MODE0 = 2'b00;
defparam dpb_inst_13.WRITE_MODE1 = 2'b00;
defparam dpb_inst_13.BIT_WIDTH_0 = 1;
defparam dpb_inst_13.BIT_WIDTH_1 = 1;
defparam dpb_inst_13.BLK_SEL_0 = 3'b001;
defparam dpb_inst_13.BLK_SEL_1 = 3'b001;
defparam dpb_inst_13.RESET_MODE = "SYNC";

DPB dpb_inst_14 (
    .DOA({dpb_inst_14_douta_w[14:0],dpb_inst_14_douta[7]}),
    .DOB({dpb_inst_14_doutb_w[14:0],dpb_inst_14_doutb[7]}),
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

defparam dpb_inst_14.READ_MODE0 = 1'b0;
defparam dpb_inst_14.READ_MODE1 = 1'b0;
defparam dpb_inst_14.WRITE_MODE0 = 2'b00;
defparam dpb_inst_14.WRITE_MODE1 = 2'b00;
defparam dpb_inst_14.BIT_WIDTH_0 = 1;
defparam dpb_inst_14.BIT_WIDTH_1 = 1;
defparam dpb_inst_14.BLK_SEL_0 = 3'b000;
defparam dpb_inst_14.BLK_SEL_1 = 3'b000;
defparam dpb_inst_14.RESET_MODE = "SYNC";

DPB dpb_inst_15 (
    .DOA({dpb_inst_15_douta_w[14:0],dpb_inst_15_douta[7]}),
    .DOB({dpb_inst_15_doutb_w[14:0],dpb_inst_15_doutb[7]}),
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

defparam dpb_inst_15.READ_MODE0 = 1'b0;
defparam dpb_inst_15.READ_MODE1 = 1'b0;
defparam dpb_inst_15.WRITE_MODE0 = 2'b00;
defparam dpb_inst_15.WRITE_MODE1 = 2'b00;
defparam dpb_inst_15.BIT_WIDTH_0 = 1;
defparam dpb_inst_15.BIT_WIDTH_1 = 1;
defparam dpb_inst_15.BLK_SEL_0 = 3'b001;
defparam dpb_inst_15.BLK_SEL_1 = 3'b001;
defparam dpb_inst_15.RESET_MODE = "SYNC";

DPB dpb_inst_16 (
    .DOA({dpb_inst_16_douta_w[14:0],dpb_inst_16_douta[0]}),
    .DOB({dpb_inst_16_doutb_w[14:0],dpb_inst_16_doutb[0]}),
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

defparam dpb_inst_16.READ_MODE0 = 1'b0;
defparam dpb_inst_16.READ_MODE1 = 1'b0;
defparam dpb_inst_16.WRITE_MODE0 = 2'b00;
defparam dpb_inst_16.WRITE_MODE1 = 2'b00;
defparam dpb_inst_16.BIT_WIDTH_0 = 1;
defparam dpb_inst_16.BIT_WIDTH_1 = 1;
defparam dpb_inst_16.BLK_SEL_0 = 3'b010;
defparam dpb_inst_16.BLK_SEL_1 = 3'b010;
defparam dpb_inst_16.RESET_MODE = "SYNC";

DPB dpb_inst_17 (
    .DOA({dpb_inst_17_douta_w[14:0],dpb_inst_17_douta[1]}),
    .DOB({dpb_inst_17_doutb_w[14:0],dpb_inst_17_doutb[1]}),
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

defparam dpb_inst_17.READ_MODE0 = 1'b0;
defparam dpb_inst_17.READ_MODE1 = 1'b0;
defparam dpb_inst_17.WRITE_MODE0 = 2'b00;
defparam dpb_inst_17.WRITE_MODE1 = 2'b00;
defparam dpb_inst_17.BIT_WIDTH_0 = 1;
defparam dpb_inst_17.BIT_WIDTH_1 = 1;
defparam dpb_inst_17.BLK_SEL_0 = 3'b010;
defparam dpb_inst_17.BLK_SEL_1 = 3'b010;
defparam dpb_inst_17.RESET_MODE = "SYNC";

DPB dpb_inst_18 (
    .DOA({dpb_inst_18_douta_w[14:0],dpb_inst_18_douta[2]}),
    .DOB({dpb_inst_18_doutb_w[14:0],dpb_inst_18_doutb[2]}),
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

defparam dpb_inst_18.READ_MODE0 = 1'b0;
defparam dpb_inst_18.READ_MODE1 = 1'b0;
defparam dpb_inst_18.WRITE_MODE0 = 2'b00;
defparam dpb_inst_18.WRITE_MODE1 = 2'b00;
defparam dpb_inst_18.BIT_WIDTH_0 = 1;
defparam dpb_inst_18.BIT_WIDTH_1 = 1;
defparam dpb_inst_18.BLK_SEL_0 = 3'b010;
defparam dpb_inst_18.BLK_SEL_1 = 3'b010;
defparam dpb_inst_18.RESET_MODE = "SYNC";

DPB dpb_inst_19 (
    .DOA({dpb_inst_19_douta_w[14:0],dpb_inst_19_douta[3]}),
    .DOB({dpb_inst_19_doutb_w[14:0],dpb_inst_19_doutb[3]}),
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

defparam dpb_inst_19.READ_MODE0 = 1'b0;
defparam dpb_inst_19.READ_MODE1 = 1'b0;
defparam dpb_inst_19.WRITE_MODE0 = 2'b00;
defparam dpb_inst_19.WRITE_MODE1 = 2'b00;
defparam dpb_inst_19.BIT_WIDTH_0 = 1;
defparam dpb_inst_19.BIT_WIDTH_1 = 1;
defparam dpb_inst_19.BLK_SEL_0 = 3'b010;
defparam dpb_inst_19.BLK_SEL_1 = 3'b010;
defparam dpb_inst_19.RESET_MODE = "SYNC";

DPB dpb_inst_20 (
    .DOA({dpb_inst_20_douta_w[14:0],dpb_inst_20_douta[4]}),
    .DOB({dpb_inst_20_doutb_w[14:0],dpb_inst_20_doutb[4]}),
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

defparam dpb_inst_20.READ_MODE0 = 1'b0;
defparam dpb_inst_20.READ_MODE1 = 1'b0;
defparam dpb_inst_20.WRITE_MODE0 = 2'b00;
defparam dpb_inst_20.WRITE_MODE1 = 2'b00;
defparam dpb_inst_20.BIT_WIDTH_0 = 1;
defparam dpb_inst_20.BIT_WIDTH_1 = 1;
defparam dpb_inst_20.BLK_SEL_0 = 3'b010;
defparam dpb_inst_20.BLK_SEL_1 = 3'b010;
defparam dpb_inst_20.RESET_MODE = "SYNC";

DPB dpb_inst_21 (
    .DOA({dpb_inst_21_douta_w[14:0],dpb_inst_21_douta[5]}),
    .DOB({dpb_inst_21_doutb_w[14:0],dpb_inst_21_doutb[5]}),
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

defparam dpb_inst_21.READ_MODE0 = 1'b0;
defparam dpb_inst_21.READ_MODE1 = 1'b0;
defparam dpb_inst_21.WRITE_MODE0 = 2'b00;
defparam dpb_inst_21.WRITE_MODE1 = 2'b00;
defparam dpb_inst_21.BIT_WIDTH_0 = 1;
defparam dpb_inst_21.BIT_WIDTH_1 = 1;
defparam dpb_inst_21.BLK_SEL_0 = 3'b010;
defparam dpb_inst_21.BLK_SEL_1 = 3'b010;
defparam dpb_inst_21.RESET_MODE = "SYNC";

DPB dpb_inst_22 (
    .DOA({dpb_inst_22_douta_w[14:0],dpb_inst_22_douta[6]}),
    .DOB({dpb_inst_22_doutb_w[14:0],dpb_inst_22_doutb[6]}),
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

defparam dpb_inst_22.READ_MODE0 = 1'b0;
defparam dpb_inst_22.READ_MODE1 = 1'b0;
defparam dpb_inst_22.WRITE_MODE0 = 2'b00;
defparam dpb_inst_22.WRITE_MODE1 = 2'b00;
defparam dpb_inst_22.BIT_WIDTH_0 = 1;
defparam dpb_inst_22.BIT_WIDTH_1 = 1;
defparam dpb_inst_22.BLK_SEL_0 = 3'b010;
defparam dpb_inst_22.BLK_SEL_1 = 3'b010;
defparam dpb_inst_22.RESET_MODE = "SYNC";

DPB dpb_inst_23 (
    .DOA({dpb_inst_23_douta_w[14:0],dpb_inst_23_douta[7]}),
    .DOB({dpb_inst_23_doutb_w[14:0],dpb_inst_23_doutb[7]}),
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
    .DOA({dpb_inst_24_douta_w[13:0],dpb_inst_24_douta[1:0]}),
    .DOB({dpb_inst_24_doutb_w[13:0],dpb_inst_24_doutb[1:0]}),
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

defparam dpb_inst_24.READ_MODE0 = 1'b0;
defparam dpb_inst_24.READ_MODE1 = 1'b0;
defparam dpb_inst_24.WRITE_MODE0 = 2'b00;
defparam dpb_inst_24.WRITE_MODE1 = 2'b00;
defparam dpb_inst_24.BIT_WIDTH_0 = 2;
defparam dpb_inst_24.BIT_WIDTH_1 = 2;
defparam dpb_inst_24.BLK_SEL_0 = 3'b110;
defparam dpb_inst_24.BLK_SEL_1 = 3'b110;
defparam dpb_inst_24.RESET_MODE = "SYNC";

DPB dpb_inst_25 (
    .DOA({dpb_inst_25_douta_w[13:0],dpb_inst_25_douta[3:2]}),
    .DOB({dpb_inst_25_doutb_w[13:0],dpb_inst_25_doutb[3:2]}),
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

defparam dpb_inst_25.READ_MODE0 = 1'b0;
defparam dpb_inst_25.READ_MODE1 = 1'b0;
defparam dpb_inst_25.WRITE_MODE0 = 2'b00;
defparam dpb_inst_25.WRITE_MODE1 = 2'b00;
defparam dpb_inst_25.BIT_WIDTH_0 = 2;
defparam dpb_inst_25.BIT_WIDTH_1 = 2;
defparam dpb_inst_25.BLK_SEL_0 = 3'b110;
defparam dpb_inst_25.BLK_SEL_1 = 3'b110;
defparam dpb_inst_25.RESET_MODE = "SYNC";

DPB dpb_inst_26 (
    .DOA({dpb_inst_26_douta_w[13:0],dpb_inst_26_douta[5:4]}),
    .DOB({dpb_inst_26_doutb_w[13:0],dpb_inst_26_doutb[5:4]}),
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

defparam dpb_inst_26.READ_MODE0 = 1'b0;
defparam dpb_inst_26.READ_MODE1 = 1'b0;
defparam dpb_inst_26.WRITE_MODE0 = 2'b00;
defparam dpb_inst_26.WRITE_MODE1 = 2'b00;
defparam dpb_inst_26.BIT_WIDTH_0 = 2;
defparam dpb_inst_26.BIT_WIDTH_1 = 2;
defparam dpb_inst_26.BLK_SEL_0 = 3'b110;
defparam dpb_inst_26.BLK_SEL_1 = 3'b110;
defparam dpb_inst_26.RESET_MODE = "SYNC";

DPB dpb_inst_27 (
    .DOA({dpb_inst_27_douta_w[13:0],dpb_inst_27_douta[7:6]}),
    .DOB({dpb_inst_27_doutb_w[13:0],dpb_inst_27_doutb[7:6]}),
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
    .DOA({dpb_inst_28_douta_w[7:0],dpb_inst_28_douta[7:0]}),
    .DOB({dpb_inst_28_doutb_w[7:0],dpb_inst_28_doutb[7:0]}),
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
    .ADA({ada[10:0],gw_gnd,gw_gnd,gw_gnd}),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[7:0]}),
    .ADB({adb[10:0],gw_gnd,gw_gnd,gw_gnd}),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[7:0]})
);

defparam dpb_inst_28.READ_MODE0 = 1'b0;
defparam dpb_inst_28.READ_MODE1 = 1'b0;
defparam dpb_inst_28.WRITE_MODE0 = 2'b00;
defparam dpb_inst_28.WRITE_MODE1 = 2'b00;
defparam dpb_inst_28.BIT_WIDTH_0 = 8;
defparam dpb_inst_28.BIT_WIDTH_1 = 8;
defparam dpb_inst_28.BLK_SEL_0 = 3'b001;
defparam dpb_inst_28.BLK_SEL_1 = 3'b001;
defparam dpb_inst_28.RESET_MODE = "SYNC";

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
MUX2 mux_inst_13 (
  .O(mux_o_13),
  .I0(dpb_inst_24_douta[0]),
  .I1(dpb_inst_28_douta[0]),
  .S0(dff_q_2)
);
MUX2 mux_inst_14 (
  .O(mux_o_14),
  .I0(dpb_inst_0_douta[0]),
  .I1(dpb_inst_1_douta[0]),
  .S0(dff_q_1)
);
MUX2 mux_inst_15 (
  .O(mux_o_15),
  .I0(dpb_inst_16_douta[0]),
  .I1(mux_o_13),
  .S0(dff_q_1)
);
MUX2 mux_inst_16 (
  .O(douta[0]),
  .I0(mux_o_14),
  .I1(mux_o_15),
  .S0(dff_q_0)
);
MUX2 mux_inst_30 (
  .O(mux_o_30),
  .I0(dpb_inst_24_douta[1]),
  .I1(dpb_inst_28_douta[1]),
  .S0(dff_q_2)
);
MUX2 mux_inst_31 (
  .O(mux_o_31),
  .I0(dpb_inst_2_douta[1]),
  .I1(dpb_inst_3_douta[1]),
  .S0(dff_q_1)
);
MUX2 mux_inst_32 (
  .O(mux_o_32),
  .I0(dpb_inst_17_douta[1]),
  .I1(mux_o_30),
  .S0(dff_q_1)
);
MUX2 mux_inst_33 (
  .O(douta[1]),
  .I0(mux_o_31),
  .I1(mux_o_32),
  .S0(dff_q_0)
);
MUX2 mux_inst_47 (
  .O(mux_o_47),
  .I0(dpb_inst_25_douta[2]),
  .I1(dpb_inst_28_douta[2]),
  .S0(dff_q_2)
);
MUX2 mux_inst_48 (
  .O(mux_o_48),
  .I0(dpb_inst_4_douta[2]),
  .I1(dpb_inst_5_douta[2]),
  .S0(dff_q_1)
);
MUX2 mux_inst_49 (
  .O(mux_o_49),
  .I0(dpb_inst_18_douta[2]),
  .I1(mux_o_47),
  .S0(dff_q_1)
);
MUX2 mux_inst_50 (
  .O(douta[2]),
  .I0(mux_o_48),
  .I1(mux_o_49),
  .S0(dff_q_0)
);
MUX2 mux_inst_64 (
  .O(mux_o_64),
  .I0(dpb_inst_25_douta[3]),
  .I1(dpb_inst_28_douta[3]),
  .S0(dff_q_2)
);
MUX2 mux_inst_65 (
  .O(mux_o_65),
  .I0(dpb_inst_6_douta[3]),
  .I1(dpb_inst_7_douta[3]),
  .S0(dff_q_1)
);
MUX2 mux_inst_66 (
  .O(mux_o_66),
  .I0(dpb_inst_19_douta[3]),
  .I1(mux_o_64),
  .S0(dff_q_1)
);
MUX2 mux_inst_67 (
  .O(douta[3]),
  .I0(mux_o_65),
  .I1(mux_o_66),
  .S0(dff_q_0)
);
MUX2 mux_inst_81 (
  .O(mux_o_81),
  .I0(dpb_inst_26_douta[4]),
  .I1(dpb_inst_28_douta[4]),
  .S0(dff_q_2)
);
MUX2 mux_inst_82 (
  .O(mux_o_82),
  .I0(dpb_inst_8_douta[4]),
  .I1(dpb_inst_9_douta[4]),
  .S0(dff_q_1)
);
MUX2 mux_inst_83 (
  .O(mux_o_83),
  .I0(dpb_inst_20_douta[4]),
  .I1(mux_o_81),
  .S0(dff_q_1)
);
MUX2 mux_inst_84 (
  .O(douta[4]),
  .I0(mux_o_82),
  .I1(mux_o_83),
  .S0(dff_q_0)
);
MUX2 mux_inst_98 (
  .O(mux_o_98),
  .I0(dpb_inst_26_douta[5]),
  .I1(dpb_inst_28_douta[5]),
  .S0(dff_q_2)
);
MUX2 mux_inst_99 (
  .O(mux_o_99),
  .I0(dpb_inst_10_douta[5]),
  .I1(dpb_inst_11_douta[5]),
  .S0(dff_q_1)
);
MUX2 mux_inst_100 (
  .O(mux_o_100),
  .I0(dpb_inst_21_douta[5]),
  .I1(mux_o_98),
  .S0(dff_q_1)
);
MUX2 mux_inst_101 (
  .O(douta[5]),
  .I0(mux_o_99),
  .I1(mux_o_100),
  .S0(dff_q_0)
);
MUX2 mux_inst_115 (
  .O(mux_o_115),
  .I0(dpb_inst_27_douta[6]),
  .I1(dpb_inst_28_douta[6]),
  .S0(dff_q_2)
);
MUX2 mux_inst_116 (
  .O(mux_o_116),
  .I0(dpb_inst_12_douta[6]),
  .I1(dpb_inst_13_douta[6]),
  .S0(dff_q_1)
);
MUX2 mux_inst_117 (
  .O(mux_o_117),
  .I0(dpb_inst_22_douta[6]),
  .I1(mux_o_115),
  .S0(dff_q_1)
);
MUX2 mux_inst_118 (
  .O(douta[6]),
  .I0(mux_o_116),
  .I1(mux_o_117),
  .S0(dff_q_0)
);
MUX2 mux_inst_132 (
  .O(mux_o_132),
  .I0(dpb_inst_27_douta[7]),
  .I1(dpb_inst_28_douta[7]),
  .S0(dff_q_2)
);
MUX2 mux_inst_133 (
  .O(mux_o_133),
  .I0(dpb_inst_14_douta[7]),
  .I1(dpb_inst_15_douta[7]),
  .S0(dff_q_1)
);
MUX2 mux_inst_134 (
  .O(mux_o_134),
  .I0(dpb_inst_23_douta[7]),
  .I1(mux_o_132),
  .S0(dff_q_1)
);
MUX2 mux_inst_135 (
  .O(douta[7]),
  .I0(mux_o_133),
  .I1(mux_o_134),
  .S0(dff_q_0)
);
MUX2 mux_inst_149 (
  .O(mux_o_149),
  .I0(dpb_inst_24_doutb[0]),
  .I1(dpb_inst_28_doutb[0]),
  .S0(dff_q_5)
);
MUX2 mux_inst_150 (
  .O(mux_o_150),
  .I0(dpb_inst_0_doutb[0]),
  .I1(dpb_inst_1_doutb[0]),
  .S0(dff_q_4)
);
MUX2 mux_inst_151 (
  .O(mux_o_151),
  .I0(dpb_inst_16_doutb[0]),
  .I1(mux_o_149),
  .S0(dff_q_4)
);
MUX2 mux_inst_152 (
  .O(doutb[0]),
  .I0(mux_o_150),
  .I1(mux_o_151),
  .S0(dff_q_3)
);
MUX2 mux_inst_166 (
  .O(mux_o_166),
  .I0(dpb_inst_24_doutb[1]),
  .I1(dpb_inst_28_doutb[1]),
  .S0(dff_q_5)
);
MUX2 mux_inst_167 (
  .O(mux_o_167),
  .I0(dpb_inst_2_doutb[1]),
  .I1(dpb_inst_3_doutb[1]),
  .S0(dff_q_4)
);
MUX2 mux_inst_168 (
  .O(mux_o_168),
  .I0(dpb_inst_17_doutb[1]),
  .I1(mux_o_166),
  .S0(dff_q_4)
);
MUX2 mux_inst_169 (
  .O(doutb[1]),
  .I0(mux_o_167),
  .I1(mux_o_168),
  .S0(dff_q_3)
);
MUX2 mux_inst_183 (
  .O(mux_o_183),
  .I0(dpb_inst_25_doutb[2]),
  .I1(dpb_inst_28_doutb[2]),
  .S0(dff_q_5)
);
MUX2 mux_inst_184 (
  .O(mux_o_184),
  .I0(dpb_inst_4_doutb[2]),
  .I1(dpb_inst_5_doutb[2]),
  .S0(dff_q_4)
);
MUX2 mux_inst_185 (
  .O(mux_o_185),
  .I0(dpb_inst_18_doutb[2]),
  .I1(mux_o_183),
  .S0(dff_q_4)
);
MUX2 mux_inst_186 (
  .O(doutb[2]),
  .I0(mux_o_184),
  .I1(mux_o_185),
  .S0(dff_q_3)
);
MUX2 mux_inst_200 (
  .O(mux_o_200),
  .I0(dpb_inst_25_doutb[3]),
  .I1(dpb_inst_28_doutb[3]),
  .S0(dff_q_5)
);
MUX2 mux_inst_201 (
  .O(mux_o_201),
  .I0(dpb_inst_6_doutb[3]),
  .I1(dpb_inst_7_doutb[3]),
  .S0(dff_q_4)
);
MUX2 mux_inst_202 (
  .O(mux_o_202),
  .I0(dpb_inst_19_doutb[3]),
  .I1(mux_o_200),
  .S0(dff_q_4)
);
MUX2 mux_inst_203 (
  .O(doutb[3]),
  .I0(mux_o_201),
  .I1(mux_o_202),
  .S0(dff_q_3)
);
MUX2 mux_inst_217 (
  .O(mux_o_217),
  .I0(dpb_inst_26_doutb[4]),
  .I1(dpb_inst_28_doutb[4]),
  .S0(dff_q_5)
);
MUX2 mux_inst_218 (
  .O(mux_o_218),
  .I0(dpb_inst_8_doutb[4]),
  .I1(dpb_inst_9_doutb[4]),
  .S0(dff_q_4)
);
MUX2 mux_inst_219 (
  .O(mux_o_219),
  .I0(dpb_inst_20_doutb[4]),
  .I1(mux_o_217),
  .S0(dff_q_4)
);
MUX2 mux_inst_220 (
  .O(doutb[4]),
  .I0(mux_o_218),
  .I1(mux_o_219),
  .S0(dff_q_3)
);
MUX2 mux_inst_234 (
  .O(mux_o_234),
  .I0(dpb_inst_26_doutb[5]),
  .I1(dpb_inst_28_doutb[5]),
  .S0(dff_q_5)
);
MUX2 mux_inst_235 (
  .O(mux_o_235),
  .I0(dpb_inst_10_doutb[5]),
  .I1(dpb_inst_11_doutb[5]),
  .S0(dff_q_4)
);
MUX2 mux_inst_236 (
  .O(mux_o_236),
  .I0(dpb_inst_21_doutb[5]),
  .I1(mux_o_234),
  .S0(dff_q_4)
);
MUX2 mux_inst_237 (
  .O(doutb[5]),
  .I0(mux_o_235),
  .I1(mux_o_236),
  .S0(dff_q_3)
);
MUX2 mux_inst_251 (
  .O(mux_o_251),
  .I0(dpb_inst_27_doutb[6]),
  .I1(dpb_inst_28_doutb[6]),
  .S0(dff_q_5)
);
MUX2 mux_inst_252 (
  .O(mux_o_252),
  .I0(dpb_inst_12_doutb[6]),
  .I1(dpb_inst_13_doutb[6]),
  .S0(dff_q_4)
);
MUX2 mux_inst_253 (
  .O(mux_o_253),
  .I0(dpb_inst_22_doutb[6]),
  .I1(mux_o_251),
  .S0(dff_q_4)
);
MUX2 mux_inst_254 (
  .O(doutb[6]),
  .I0(mux_o_252),
  .I1(mux_o_253),
  .S0(dff_q_3)
);
MUX2 mux_inst_268 (
  .O(mux_o_268),
  .I0(dpb_inst_27_doutb[7]),
  .I1(dpb_inst_28_doutb[7]),
  .S0(dff_q_5)
);
MUX2 mux_inst_269 (
  .O(mux_o_269),
  .I0(dpb_inst_14_doutb[7]),
  .I1(dpb_inst_15_doutb[7]),
  .S0(dff_q_4)
);
MUX2 mux_inst_270 (
  .O(mux_o_270),
  .I0(dpb_inst_23_doutb[7]),
  .I1(mux_o_268),
  .S0(dff_q_4)
);
MUX2 mux_inst_271 (
  .O(doutb[7]),
  .I0(mux_o_269),
  .I1(mux_o_270),
  .S0(dff_q_3)
);
endmodule //Gowin_DPB
