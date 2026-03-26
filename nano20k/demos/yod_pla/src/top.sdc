//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.11.03 Education 
//Created Time: 2026-03-02 18:49:42
create_clock -name clk_27M -period 37.037 -waveform {0 18.518} [get_ports {clk}]
create_clock -name pla_clk -period 37.037 -waveform {0 18.518} [get_ports {pla_clk}]
