//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.11.03 Education 
//Created Time: 2026-03-02 18:49:42
create_clock -name clk_27M -period 37.037 -waveform {0 18.518} [get_ports {clk}]
set_false_path -from [get_regs {node0/tx_data_s0 node0/tx_clk_s2}] -to [get_regs {node1/rx_clk_pipe_0_s0 node1/rx_data_pipe_0_s0}] 
set_false_path -from [get_regs {node3/tx_data_s0 node3/tx_clk_s2}] -to [get_regs {debug_uart/tx_clk_pipe_0_s0 debug_uart/tx_data_pipe_0_s0}] 
set_false_path -from [get_regs {node2/tx_clk_s2 node2/tx_data_s0}] -to [get_regs {node3/rx_data_pipe_0_s0 node3/rx_clk_pipe_0_s0}] 
set_false_path -from [get_regs {rstcnt_3_s0}] -to [get_regs {rst_n_75_sync_0_s0 rst_n_81_sync_0_s0}] 
