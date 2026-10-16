`default_nettype none

module spi(
	input wire clk,
	input wire rst_n,
	
	input wire       valid,
	output reg       idle,

	input wire [3:0] div,			// clock divider
	input wire       cs_start,		// CS at start of transfer
	input wire       cs_end,		// CS after last bit of transfer
	input wire [7:0] mosi_byte,		// byte to send
	output reg [7:0] miso_byte,		// byte received (only valid in idle)
	
	output reg       cs_pin,
	output reg       sck_pin,
	output reg       mosi_pin,
	input  wire      miso_pin
);

	reg [3:0] timer;
	reg [2:0] curbit;
	
	always @(posedge clk) begin
		if (idle) begin
			if (valid) begin
				timer     <= div;
				miso_byte <= mosi_byte;
				cs_pin    <= cs_start;
				mosi_pin  <= mosi_byte[7];
				curbit    <= 7;
				idle	  <= 1'b0;
			end
		end else begin
			timer <= timer - 1'b1;
			if (timer == 0) begin
				timer    <= div;
				sck_pin  <= ~sck_pin;
				if (sck_pin) begin
					// pin is high going low
					curbit    <= curbit - 1'b1;
					miso_byte <= {miso_byte[6:0], miso_pin};
					mosi_pin  <= miso_byte[6];
					if (curbit == 0) begin
						// done sending
						cs_pin <= cs_end;
						idle   <= 1'b1;
					end
				end
			end
		end
	
		if (!rst_n) begin
			idle      <= 1'b1;
			cs_pin    <= 1'b1;
			sck_pin   <= 1'b0;
			mosi_pin  <= 1'b1;
			miso_byte <= 8'hFF;
			curbit    <= 0;
			timer     <= 0;
		end
	end
endmodule
