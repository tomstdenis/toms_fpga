module top(input clk, input uart_rx, inout [7:0] gpio, input pla_clk);

    localparam
        PINS = 8,
        TERMS = 16,
        W_WIDTH = 2 * (PINS + 2), 							// width of the AND block input (determines how many fuses are needed per AND)
        TOTAL_FUSES	= 2 * PINS + PINS * TERMS + (1 + W_WIDTH) * TERMS;

    wire rst_n;
    wire [7:0] in_sig;
    reg [7:0] out_sig;
    reg [TOTAL_FUSES-1:0] fuses;

    pla #(.PINS(PINS), .TERMS(TERMS)) (
        .clk(clk), .rst_n(rst_n),
        .in_sig(in_sig), .out_sig(out_sig),
        .fuses(fuses));

endmodule