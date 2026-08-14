//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//Tool Version: V1.9.11.03 Education
//Part Number: GW1NZ-LV1QN48C6/I5
//Device: GW1NZ-1
//Created Time: Fri Aug 14 15:05:30 2026

module Gowin_OSC (oscout, oscen);

output oscout;
input oscen;

OSCZ osc_inst (
    .OSCOUT(oscout),
    .OSCEN(oscen)
);

defparam osc_inst.FREQ_DIV = 128;
defparam osc_inst.S_RATE = "SLOW";

endmodule //Gowin_OSC
