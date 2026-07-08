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

    reg state;
    reg [BAUD_WIDTH-1:0] bit_timer;
    reg [3:0] bit_index;
    reg [9:0] data_latch;
    always @(*) begin
		tx_pin     = (state == IDLE) ? 1'b1 : data_latch[0];
		tx_done    = (state == IDLE && bit_index == 9) ? 1'b1 : 1'b0;
		tx_started = state;
	end

    always @(posedge clk) begin
        if (!rst_n) begin
            state 		<= IDLE;
            data_latch 	<= 0;
            bit_timer 	<= 0;
            bit_index 	<= 9;
        end else begin
            case (state)
                IDLE: begin									// IDLE state waiting for start_tx to go high
                    if (start_tx) begin
                        data_latch <= { 1'b1, data_in, 1'b0 };	// latch the data being transmitted
                        bit_timer  <= baud_div;				// and the current baud_div
                        bit_index  <= 0;
                        state      <= DATA_BITS;
                    end
                end

                DATA_BITS: begin							// Send data bits as pulse width signals
                    if (bit_timer == 0) begin
						data_latch <= { 1'b0, data_latch[9:1] };
                        bit_timer  <= baud_div;
                        if (bit_index == 9) begin
                            state      <= IDLE;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        bit_timer <= bit_timer - 1'b1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
