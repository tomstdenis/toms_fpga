module top(input clk, output WS2812);
    reg led;
    assign WS2812 = led;
    always @(posedge clk) begin
        led <= led ^ 1'b1;
    end

endmodule