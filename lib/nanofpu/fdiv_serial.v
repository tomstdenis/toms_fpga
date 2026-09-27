`default_nettype none
module fdiv_serial (
    input wire         clk,
    input wire         rst,
    input wire         start,
    input wire [23:0]  sig_a,   // Dividend (24 bits)
    input wire [23:0]  sig_b,   // Divisor  (24 bits)
    output wire [24:0] quot,    // Quotient (25 bits: bit 24 or 23 will be MSB)
    output reg         done
);
    reg [49:0] acc;            // 25-bit upper remainder, 25-bit quotient accumulator
    reg [23:0] div_reg;
    reg [4:0]  count;

    wire [24:0] sub_res = acc[49:25] - div_reg;

    // Direct output of the accumulated quotient bits
    assign quot = acc[24:0];

    always @(posedge clk) begin
        if (rst) begin
            done  <= 0;
            count <= 0;
        end else if (start) begin
            acc     <= {26'b0, sig_a[23:0]}; // Align dividend
            div_reg <= sig_b;
            count   <= 25;                  // 25 iterations
            done    <= 0;
        end else if (count > 0) begin
            if (sub_res[24] == 0) begin // Subtract fits
                acc <= {sub_res[23:0], acc[24:0], 1'b1};
            end else begin              // Doesn't fit
                acc <= {acc[48:0], 1'b0};
            end
            
            count <= count - 1;
            if (count == 1) begin
                done <= 1;
            end
        end else begin
            done <= 0;
        end
    end
endmodule
