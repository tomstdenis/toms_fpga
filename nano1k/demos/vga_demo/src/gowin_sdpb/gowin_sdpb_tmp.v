//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.11.03 Education
//Part Number: GW1NZ-LV1QN48C6/I5
//Device: GW1NZ-1
//Created Time: Fri Jul 24 17:54:58 2026

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    Gowin_SDPB your_instance_name(
        .dout(dout), //output [7:0] dout
        .clka(clka), //input clka
        .cea(cea), //input cea
        .reseta(reseta), //input reseta
        .clkb(clkb), //input clkb
        .ceb(ceb), //input ceb
        .resetb(resetb), //input resetb
        .oce(oce), //input oce
        .ada(ada), //input [10:0] ada
        .din(din), //input [7:0] din
        .adb(adb) //input [10:0] adb
    );

//--------Copy end-------------------
