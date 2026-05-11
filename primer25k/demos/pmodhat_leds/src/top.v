module top(input wire clk, output wire [31:0] gpio);

    reg [24:0] count;
    reg [31:0] leds;

    initial begin
        count = 0;
        leds = 32'd0;
    end

    assign gpio = ~leds;

    always @(posedge clk) begin
        if (count == 12_500_000) begin              // 1/4 sec @ 50MHz
            count <= 0;
            //leds <= {leds[30:0], leds[31]};
//            leds <= leds + 1'b1;
  //          leds[7:0] <= {leds[6:0], leds[7]};
        end else begin
            count <= count + 1'b1;
        end
    end
endmodule