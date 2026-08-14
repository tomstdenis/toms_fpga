module top(input wire clk, output wire sdr_pin, output wire ddr_pin, output wire clk_pin);

    Gowin_OSC almost_clock(
        .oscout(clk_pin), //output oscout
        .oscen(1'b1) //input oscen
    );

    reg [15:0] counter;
    reg tick = 0;

    assign sdr_pin = tick;
	Gowin_DDR tommy_two_two(
//		.din({1'b0, tick}), //input [1:0] din       THIS produces a HIGH-LOW 
		.din({tick, 1'b0}), //input [1:0] din       THIS produces a LOW-HIGH (you want this for SPI)
		.clk(clk_pin), //input clk
		.q(ddr_pin) //output [0:0] q
	);

    always @(posedge clk_pin) begin
        counter <= counter + 1'b1;
        tick <= ((counter == 1023) || (counter == 1025)) ? 1 : 0;
    end

endmodule