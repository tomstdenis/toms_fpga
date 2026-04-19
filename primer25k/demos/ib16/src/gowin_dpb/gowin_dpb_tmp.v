//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.11.03 Education
//Part Number: GW5A-LV25MG121NC1/I0
//Device: GW5A-25
//Device Version: A
//Created Time: Sun Apr 19 12:29:56 2026

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    Gowin_DPB your_instance_name(
        .douta(douta), //output [7:0] douta
        .doutb(doutb), //output [7:0] doutb
        .clka(clka), //input clka
        .ocea(ocea), //input ocea
        .cea(cea), //input cea
        .reseta(reseta), //input reseta
        .wrea(wrea), //input wrea
        .clkb(clkb), //input clkb
        .oceb(oceb), //input oceb
        .ceb(ceb), //input ceb
        .resetb(resetb), //input resetb
        .wreb(wreb), //input wreb
        .ada(ada), //input [15:0] ada
        .dina(dina), //input [7:0] dina
        .adb(adb), //input [15:0] adb
        .dinb(dinb) //input [7:0] dinb
    );

//--------Copy end-------------------
