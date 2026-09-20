//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.11.03 Education 
//Created Time: 2026-09-12 21:15:26
create_clock -name clk_50M -period 20 -waveform {0 10} [get_ports {clk}]
set_false_path -from [get_regs {lt1000soc/cvga_page_sel_s0}] -to [get_regs {lt1000soc/vga_page_sel_0_s0}] 
set_false_path -from [get_regs {lt1000soc/vga_h_blank_l_s0}] -to [get_regs {lt1000soc/cvga_h_blank_0_s0}] 
set_false_path -from [get_regs {lt1000soc/cvga_video_mode_s0}] -to [get_regs {lt1000soc/vga_video_mode_0_s0}] 
set_false_path -from [get_regs {lt1000soc/vga_v_blank_l_s0}] -to [get_regs {lt1000soc/cvga_v_blank_0_s0}] 
