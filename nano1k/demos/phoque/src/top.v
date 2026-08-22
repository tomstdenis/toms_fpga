// AUTO-GENERATED USING Seal-Lang 2026.8a ON 2026/08/22 - DO NOT EDIT FILE (don't tell me what to do!)

`default_nettype none

// Blinky
module _ZN6BlinkyE (
    input wire clk,
    output wire led_r,
    output wire led_g,
    output wire led_b
);

reg [25:0] t;

wire [31:0] w4;
wire [6:0] w5;
wire [6:0] w10;
wire [6:0] w16;
wire [6:0] w19;
wire [6:0] w25;
wire [6:0] w28;


assign w4 = t >> 32'd19;
assign w5 = w4[6:0];
assign w10 = 7'd127 - w5;
assign w16 = w5 + 7'd42;
assign w19 = 7'd127 - w16;
assign w25 = w5 + 7'd85;
assign w28 = 7'd127 - w25;
assign led_r = ~(t[5:0] < (w5 < 7'd64 ? w5[5:0] : w10[5:0]));
assign led_g = ~(t[5:0] < (w16 < 7'd64 ? w16[5:0] : w19[5:0]));
assign led_b = ~(t[5:0] < (w25 < 7'd64 ? w25[5:0] : w28[5:0]));

initial begin
    t <= 26'd0;
end

always @(posedge clk) begin
    // main.seal:47  t = t + 1;
    t <= t + 26'd1;
end

endmodule