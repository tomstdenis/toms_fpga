/* Simple timing generator for VGA @ 640x480x60fps */

`timescale 1ns/1ps
`default_nettype none

module vga_640x480_timing (
    input  wire        clk,   // 25.175 MHz
    input  wire        rst,
    output reg  [9:0]  x,
    output reg  [9:0]  y,
    output reg         h_sync,
    output reg         v_sync,
    output wire        active_video
);

    // Horizontal constants
    localparam H_VISIBLE    = 640;
    localparam H_FRONT      = 16;
    localparam H_SYNC       = 96;
    localparam H_BACK       = 48;
    localparam H_TOTAL      = 800;

    // Vertical constants
    localparam V_VISIBLE    = 480;
    localparam V_FRONT      = 10;
    localparam V_SYNC       = 2;
    localparam V_BACK       = 33;
    localparam V_TOTAL      = 525;

    // Active video flag (high when inside the 640x480 area)
    assign active_video = (x < H_VISIBLE) && (y < V_VISIBLE);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x <= 0;
            y <= 0;
            h_sync <= 1;
            v_sync <= 1;
        end else begin
            // X and Y Counter Logic
            if (x == H_TOTAL - 1) begin
                x <= 0;
                if (y == V_TOTAL - 1)
                    y <= 0;
                else
                    y <= y + 1;
            end else begin
                x <= x + 1;
            end

            // Horizontal Sync (Active Low for 640x480)
            h_sync <= ~((x >= (H_VISIBLE + H_FRONT)) && 
                        (x < (H_VISIBLE + H_FRONT + H_SYNC)));

            // Vertical Sync (Active Low for 640x480)
            v_sync <= ~((y >= (V_VISIBLE + V_FRONT)) && 
                        (y < (V_VISIBLE + V_FRONT + V_SYNC)));
        end
    end

endmodule
