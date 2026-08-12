/*

                         USB JTAG           USB HOST                           
                            ▲                  ▲                               
                            │                  │                               
                            │                  │                               
                        ┌───┴──────────────────┴──────┐                        
(gpio[39:32]) PMOD4 ◄───┤                             ├───► PMOD3 (gpio[31:24])
                        │   │   ┌─────────────┐  │    │                        
                        │   │   │             │  │    │                        
(gpio(47:40]) PMOD5 ◄───┤   │   │             │  │    ├───► PMOD2 (gpio(23:16])
                        │   │   │     SOM     │  │    │                        
                        │   │   │             │  │    │                        
(gpio(55:48]) PMOD6 ◄───┤   │   │             │  │    ├───► PMOD1 (gpio[15:8]) 
                        │   │   │             │  │    │                        
                        │   │   └─────────────┘  │    │                        
(gpio[63:56]) PMOD7 ◄───┤   │                    │    ├───► PMOD0 (gpio[7:0])  
                        │                             │                        
                        └─────────────────────────────┘                        


PMOD layout:
      ┌─────────────────────────┐
      │ VCC GND 0   1   2   3   │
      │ VCC GND 4   5   6   7   │
      └─────────────────────────┘

*/


module top(input wire clk, output wire [63:0] gpio);

    reg [24:0] count;
    reg [63:0] leds;

    initial begin
        count = 0;
        leds = 1;
//        leds = {8'd1, 8'd1, 8'd1, 8'd1};
//        leds = {8'd0, 8'd0, 8'd0, 8'd1};
    end

    assign gpio = ~leds;

    always @(posedge clk) begin
        if (count == 15_000_000) begin
            count <= 0;
//leds[8] <= ~leds[8]; 
//leds[31:0] <= ~leds[31:0];
//leds <= ~leds;
//leds <= leds + 1'b1;
//              leds[7:0] <= ~leds[7:0];
//              leds[15:8] <= ~leds[15:8];
//              leds[23:16] <= ~leds[23:16];
//              leds[31:24] <= ~leds[31:24];
              //leds[39:32] <= ~leds[39:32];
//            leds[8] <= ~leds[8];
            leds <= {leds[62:0], leds[63]};
//            leds <= leds + 1'b1;

//            leds[7:0] <= {leds[6:0], leds[7]};
//            leds[15:8] <= {leds[14:8], leds[15]};
//            leds[23:16] <= {leds[22:16], leds[23]};
//            leds[31:24] <= {leds[30:24], leds[31]};

        end else begin
            count <= count + 1'b1;
        end
    end
endmodule

