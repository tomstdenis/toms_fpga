`timescale 1ns/1ps
`default_nettype none

// Serial 8N1 transmitter with variable baudrate
module tx_uart
#(parameter BAUD_WIDTH=12)
(
    input wire clk,                          
    input wire rst_n,                        // active low reset
    input wire [BAUD_WIDTH-1:0] baud_div,    // counter value for baud calculation (e.g. F_CLK/BAUD == baud_div)
    input wire start_tx,                     // active high start transmitting whatever is in data_in (which is latched after the first cycle)
    input wire [7:0] data_in,
    output reg tx_pin,                  // (out) the TX pin
    output reg tx_started,              // (out) Indicates transmission started
    output reg tx_done                  // (out) indicates TX done
);
    logic [BAUD_WIDTH-1:0] bit_timer;
    logic [9:0] data_latch;
	logic state;

    always_comb begin
		tx_pin     = (state == 0) ? 1'b1 : data_latch[0];
		tx_done    = (state == 0) ? 1'b1 : 1'b0;
		tx_started = state;
	end
	
    always_ff @(posedge clk) begin
        if (~rst_n) begin
			bit_timer  <= baud_div;							// and the current baud_div
            data_latch <= 0;
            state      <= 0;
        end else begin
			if (~state) begin
				data_latch <= { start_tx, data_in, 1'b0 };	// latch the data being transmitted
				state      <= start_tx;
			end else if (state) begin
				if (bit_timer == 0) begin
					bit_timer  <= baud_div;
					data_latch <= { 1'b0, data_latch[9:1] };
					state      <= |data_latch[9:1];
				end else begin
					bit_timer <= bit_timer - 1'b1;
				end
			end
		end
	end
endmodule
