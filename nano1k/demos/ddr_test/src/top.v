module top(input wire clk, output wire sdr_pin, output wire ddr_pin, output wire clk_pin, output reg [3:0] sio);

    Gowin_OSC almost_clock(
        .oscout(clk_pin), //output oscout
        .oscen(1'b1) //input oscen
    );

    reg [15:0] counter;
    reg tick = 0;

	Gowin_DDR tommy_two_two(
//		.din({1'b0, tick}), //input [1:0] din       THIS produces a HIGH-LOW 
		.din({1'b1, 1'b0}), //input [1:0] din       THIS produces a LOW-HIGH (you want this for SPI)
		.clk(clk_pin), //input clk
		.q(ddr_pin) //output [0:0] q
	);

    assign sdr_pin = tick;

    always @(posedge clk_pin) begin
        counter <= counter + 1'b1;
        sio  <= 4'b0000;
        tick <= 1'b1;
        case (counter)
            1023:
                begin
                    tick <= 1'b0;
                    sio  <= 4'b1010;
                end
            1024:
                begin
                    tick <= 1'b0;
                    sio  <= 4'b0101;
                end
            1025: tick <= 1'b0;
        endcase
    end

endmodule