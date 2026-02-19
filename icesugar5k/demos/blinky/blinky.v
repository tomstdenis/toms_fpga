module top (
    input  clk,
    output led
);
    // 24-bit counter (2^23 is roughly 8 million, @12MHz = ~0.7s toggle)
    reg [23:0] counter;

    always @(posedge clk) begin
        counter <= counter + 1;
    end

    assign led = counter[23];
endmodule

