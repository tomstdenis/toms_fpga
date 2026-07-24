module top(input wire clk, output wire [23:0] gpio);

    reg [24:0] count;
    reg [23:0] leds;

    initial begin
        count = 0;
        leds = {8'd0, 8'd0, 8'd1};
   end

    assign gpio = ~leds;

    always @(posedge clk) begin
        if (count == 12_500_000) begin              // 1/4 sec @ 50MHz
            count <= 0;
            leds <= {leds[22:0], leds[23]};
//            leds <= leds + 1'b1;
/*
            leds[7:0] <= {leds[6:0], leds[7]};
            leds[15:8] <= {leds[14:8], leds[15]};
            leds[23:16] <= {leds[22:16], leds[23]};
            leds[31:24] <= {leds[30:24], leds[31]};
*/
        end else begin
            count <= count + 1'b1;
        end
    end
endmodule