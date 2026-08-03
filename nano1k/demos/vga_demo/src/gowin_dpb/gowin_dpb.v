//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//Tool Version: V1.9.11.03 Education
//Part Number: GW1NZ-LV1QN48C6/I5
//Device: GW1NZ-1
//Created Time: Sun Aug  2 22:05:51 2026
`default_nettype wire
module Gowin_DPB (douta, doutb, clka, ocea, cea, reseta, wrea, clkb, oceb, ceb, resetb, wreb, ada, dina, adb, dinb);

output [15:0] douta;
output [15:0] doutb;
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
input [10:0] ada;
input [15:0] dina;
input [10:0] adb;
input [15:0] dinb;

wire [15:0] dpb_inst_0_douta;
wire [15:0] dpb_inst_0_doutb;
wire [15:0] dpb_inst_1_douta;
wire [15:0] dpb_inst_1_doutb;
wire dff_q_0;
wire dff_q_1;
wire cea_w;
wire ceb_w;
wire gw_vcc;
wire gw_gnd;

assign cea_w = ~wrea & cea;
assign ceb_w = ~wreb & ceb;
assign gw_vcc = 1'b1;
assign gw_gnd = 1'b0;

DPB dpb_inst_0 (
    .DOA(dpb_inst_0_douta[15:0]),
    .DOB(dpb_inst_0_doutb[15:0]),
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
    .BLKSELA({gw_gnd,gw_gnd,ada[10]}),
    .BLKSELB({gw_gnd,gw_gnd,adb[10]}),
    .ADA({ada[9:0],gw_gnd,gw_gnd,gw_vcc,gw_vcc}),
    .DIA(dina[15:0]),
    .ADB({adb[9:0],gw_gnd,gw_gnd,gw_vcc,gw_vcc}),
    .DIB(dinb[15:0])
);

defparam dpb_inst_0.READ_MODE0 = 1'b0;
defparam dpb_inst_0.READ_MODE1 = 1'b0;
defparam dpb_inst_0.WRITE_MODE0 = 2'b00;
defparam dpb_inst_0.WRITE_MODE1 = 2'b00;
defparam dpb_inst_0.BIT_WIDTH_0 = 16;
defparam dpb_inst_0.BIT_WIDTH_1 = 16;
defparam dpb_inst_0.BLK_SEL_0 = 3'b000;
defparam dpb_inst_0.BLK_SEL_1 = 3'b000;
defparam dpb_inst_0.RESET_MODE = "SYNC";

DPB dpb_inst_1 (
    .DOA(dpb_inst_1_douta[15:0]),
    .DOB(dpb_inst_1_doutb[15:0]),
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
    .BLKSELA({gw_gnd,gw_gnd,ada[10]}),
    .BLKSELB({gw_gnd,gw_gnd,adb[10]}),
    .ADA({ada[9:0],gw_gnd,gw_gnd,gw_vcc,gw_vcc}),
    .DIA(dina[15:0]),
    .ADB({adb[9:0],gw_gnd,gw_gnd,gw_vcc,gw_vcc}),
    .DIB(dinb[15:0])
);

defparam dpb_inst_1.READ_MODE0 = 1'b0;
defparam dpb_inst_1.READ_MODE1 = 1'b0;
defparam dpb_inst_1.WRITE_MODE0 = 2'b00;
defparam dpb_inst_1.WRITE_MODE1 = 2'b00;
defparam dpb_inst_1.BIT_WIDTH_0 = 16;
defparam dpb_inst_1.BIT_WIDTH_1 = 16;
defparam dpb_inst_1.BLK_SEL_0 = 3'b001;
defparam dpb_inst_1.BLK_SEL_1 = 3'b001;
defparam dpb_inst_1.RESET_MODE = "SYNC";

DFFE dff_inst_0 (
  .Q(dff_q_0),
  .D(ada[10]),
  .CLK(clka),
  .CE(cea_w)
);
DFFE dff_inst_1 (
  .Q(dff_q_1),
  .D(adb[10]),
  .CLK(clkb),
  .CE(ceb_w)
);
MUX2 mux_inst_0 (
  .O(douta[0]),
  .I0(dpb_inst_0_douta[0]),
  .I1(dpb_inst_1_douta[0]),
  .S0(dff_q_0)
);
MUX2 mux_inst_1 (
  .O(douta[1]),
  .I0(dpb_inst_0_douta[1]),
  .I1(dpb_inst_1_douta[1]),
  .S0(dff_q_0)
);
MUX2 mux_inst_2 (
  .O(douta[2]),
  .I0(dpb_inst_0_douta[2]),
  .I1(dpb_inst_1_douta[2]),
  .S0(dff_q_0)
);
MUX2 mux_inst_3 (
  .O(douta[3]),
  .I0(dpb_inst_0_douta[3]),
  .I1(dpb_inst_1_douta[3]),
  .S0(dff_q_0)
);
MUX2 mux_inst_4 (
  .O(douta[4]),
  .I0(dpb_inst_0_douta[4]),
  .I1(dpb_inst_1_douta[4]),
  .S0(dff_q_0)
);
MUX2 mux_inst_5 (
  .O(douta[5]),
  .I0(dpb_inst_0_douta[5]),
  .I1(dpb_inst_1_douta[5]),
  .S0(dff_q_0)
);
MUX2 mux_inst_6 (
  .O(douta[6]),
  .I0(dpb_inst_0_douta[6]),
  .I1(dpb_inst_1_douta[6]),
  .S0(dff_q_0)
);
MUX2 mux_inst_7 (
  .O(douta[7]),
  .I0(dpb_inst_0_douta[7]),
  .I1(dpb_inst_1_douta[7]),
  .S0(dff_q_0)
);
MUX2 mux_inst_8 (
  .O(douta[8]),
  .I0(dpb_inst_0_douta[8]),
  .I1(dpb_inst_1_douta[8]),
  .S0(dff_q_0)
);
MUX2 mux_inst_9 (
  .O(douta[9]),
  .I0(dpb_inst_0_douta[9]),
  .I1(dpb_inst_1_douta[9]),
  .S0(dff_q_0)
);
MUX2 mux_inst_10 (
  .O(douta[10]),
  .I0(dpb_inst_0_douta[10]),
  .I1(dpb_inst_1_douta[10]),
  .S0(dff_q_0)
);
MUX2 mux_inst_11 (
  .O(douta[11]),
  .I0(dpb_inst_0_douta[11]),
  .I1(dpb_inst_1_douta[11]),
  .S0(dff_q_0)
);
MUX2 mux_inst_12 (
  .O(douta[12]),
  .I0(dpb_inst_0_douta[12]),
  .I1(dpb_inst_1_douta[12]),
  .S0(dff_q_0)
);
MUX2 mux_inst_13 (
  .O(douta[13]),
  .I0(dpb_inst_0_douta[13]),
  .I1(dpb_inst_1_douta[13]),
  .S0(dff_q_0)
);
MUX2 mux_inst_14 (
  .O(douta[14]),
  .I0(dpb_inst_0_douta[14]),
  .I1(dpb_inst_1_douta[14]),
  .S0(dff_q_0)
);
MUX2 mux_inst_15 (
  .O(douta[15]),
  .I0(dpb_inst_0_douta[15]),
  .I1(dpb_inst_1_douta[15]),
  .S0(dff_q_0)
);
MUX2 mux_inst_16 (
  .O(doutb[0]),
  .I0(dpb_inst_0_doutb[0]),
  .I1(dpb_inst_1_doutb[0]),
  .S0(dff_q_1)
);
MUX2 mux_inst_17 (
  .O(doutb[1]),
  .I0(dpb_inst_0_doutb[1]),
  .I1(dpb_inst_1_doutb[1]),
  .S0(dff_q_1)
);
MUX2 mux_inst_18 (
  .O(doutb[2]),
  .I0(dpb_inst_0_doutb[2]),
  .I1(dpb_inst_1_doutb[2]),
  .S0(dff_q_1)
);
MUX2 mux_inst_19 (
  .O(doutb[3]),
  .I0(dpb_inst_0_doutb[3]),
  .I1(dpb_inst_1_doutb[3]),
  .S0(dff_q_1)
);
MUX2 mux_inst_20 (
  .O(doutb[4]),
  .I0(dpb_inst_0_doutb[4]),
  .I1(dpb_inst_1_doutb[4]),
  .S0(dff_q_1)
);
MUX2 mux_inst_21 (
  .O(doutb[5]),
  .I0(dpb_inst_0_doutb[5]),
  .I1(dpb_inst_1_doutb[5]),
  .S0(dff_q_1)
);
MUX2 mux_inst_22 (
  .O(doutb[6]),
  .I0(dpb_inst_0_doutb[6]),
  .I1(dpb_inst_1_doutb[6]),
  .S0(dff_q_1)
);
MUX2 mux_inst_23 (
  .O(doutb[7]),
  .I0(dpb_inst_0_doutb[7]),
  .I1(dpb_inst_1_doutb[7]),
  .S0(dff_q_1)
);
MUX2 mux_inst_24 (
  .O(doutb[8]),
  .I0(dpb_inst_0_doutb[8]),
  .I1(dpb_inst_1_doutb[8]),
  .S0(dff_q_1)
);
MUX2 mux_inst_25 (
  .O(doutb[9]),
  .I0(dpb_inst_0_doutb[9]),
  .I1(dpb_inst_1_doutb[9]),
  .S0(dff_q_1)
);
MUX2 mux_inst_26 (
  .O(doutb[10]),
  .I0(dpb_inst_0_doutb[10]),
  .I1(dpb_inst_1_doutb[10]),
  .S0(dff_q_1)
);
MUX2 mux_inst_27 (
  .O(doutb[11]),
  .I0(dpb_inst_0_doutb[11]),
  .I1(dpb_inst_1_doutb[11]),
  .S0(dff_q_1)
);
MUX2 mux_inst_28 (
  .O(doutb[12]),
  .I0(dpb_inst_0_doutb[12]),
  .I1(dpb_inst_1_doutb[12]),
  .S0(dff_q_1)
);
MUX2 mux_inst_29 (
  .O(doutb[13]),
  .I0(dpb_inst_0_doutb[13]),
  .I1(dpb_inst_1_doutb[13]),
  .S0(dff_q_1)
);
MUX2 mux_inst_30 (
  .O(doutb[14]),
  .I0(dpb_inst_0_doutb[14]),
  .I1(dpb_inst_1_doutb[14]),
  .S0(dff_q_1)
);
MUX2 mux_inst_31 (
  .O(doutb[15]),
  .I0(dpb_inst_0_doutb[15]),
  .I1(dpb_inst_1_doutb[15]),
  .S0(dff_q_1)
);
endmodule //Gowin_DPB
