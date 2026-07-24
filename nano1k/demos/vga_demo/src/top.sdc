//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.11.03 Education 
//Created Time: 2026-03-31 23:16:02
create_clock -name clk_27M -period 37.037 -waveform {0 18.518} [get_ports {clk}]
//set_multicycle_path -from [get_clocks {clk_27M}] -through [get_nets {ittybitty/result_dff[0]}] -to [get_clocks {clk_27M}]  -setup -end 2
