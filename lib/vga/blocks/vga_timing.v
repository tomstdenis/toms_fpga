/* Simple timing generator for VGA (default:640x480x60fps) */

`timescale 1ns/1ps
`default_nettype none

module vga_timing #(
    // Horizontal constants
    parameter H_VISIBLE    = 640,
    parameter H_FRONT      = 16,
    parameter H_SYNC       = 96,
    parameter H_BACK       = 48,
    parameter H_TOTAL      = 800,

    // Vertical constants
    parameter V_VISIBLE    = 480,
    parameter V_FRONT      = 10,
    parameter V_SYNC       = 2,
    parameter V_BACK       = 33,
    parameter V_TOTAL      = 525
)

(
    input  wire        clk,   // e.g., 640x480@60 == 25.175 MHz
    input  wire        rst,
    output reg  [$clog2(H_TOTAL):0]  x,
    output reg  [$clog2(V_TOTAL):0]  y,
    output reg         h_sync,
    output reg         v_sync,
    output wire        active_video
);

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
