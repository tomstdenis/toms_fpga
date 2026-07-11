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
    localparam
        IDLE      = 1'd0, // waiting for a byte
        DATA_BITS = 1'd1; // reading in data bits

    logic state;
    logic [BAUD_WIDTH-1:0] bit_timer;
    logic [3:0] bit_index;
    logic [9:0] data_latch;
    always @(*) begin
		tx_pin     = (state == IDLE) ? 1'b1 : data_latch[0];
		tx_done    = (state == IDLE && bit_index == 9) ? 1'b1 : 1'b0;
		tx_started = state;
	end

    always @(posedge clk) begin
        if (~rst_n) begin
            state 	   <= IDLE;
			bit_timer  <= baud_div;							// and the current baud_div
            bit_index  <= 9;
        end else begin
			if (~state) begin
				bit_index  <= {~start_tx, 1'b0, 1'b0, ~start_tx};
				state      <= start_tx;
			end else if (state) begin
				if (bit_timer == 0) begin
					bit_timer  <= baud_div;
					if (bit_index == 9) begin
						state  <= IDLE;
					end else begin
						bit_index <= bit_index + 1'b1;
					end
				end else begin
					bit_timer <= bit_timer - 1'b1;
				end
			end
		end
	end

    always @(posedge clk) begin
		if (~state) begin
			data_latch <= { 1'b1, data_in, 1'b0 };	// latch the data being transmitted
		end else if (state) begin 
			if (bit_timer == 0) begin
				data_latch <= { 1'b0, data_latch[9:1] };
			end
		end
    end
endmodule
