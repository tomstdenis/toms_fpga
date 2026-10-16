`timescale 1ns/1ps
`default_nettype none

// Serial 8N1 receive with variable baudrate
module rx_uart
#(parameter BAUD_WIDTH=12)
(
    input wire clk,                          
    input wire rst_n,                        // active low reset
    input wire [BAUD_WIDTH-1:0] baud_div,    // counter value for baud calculation (e.g. F_CLK/BAUD == baud_div)
    input wire rx_pin,                       // UART assigned pin
    input wire rx_read,                      // active high indicates when you read the byte to clear the rx_done pin
    output reg rx_done,                 	 // (out) indicates a character is ready
    output reg [7:0] rx_byte                 // (out) the character that was read
);
    localparam
        IDLE      = 1'd0, // waiting for a byte
        DATA_BITS = 1'd1; // reading in data bits

	reg [9:0] rx_data;
    reg state;
    reg [BAUD_WIDTH-1:0] bit_timer;
    reg [3:0] bit_index;
    
    always @(*) begin
		rx_done = ~state & ~rx_data[0] & rx_data[9];		// IDLE, and valid START and STOP bits
		rx_byte = rx_data[8:1];
	end
	
    always @(posedge clk) begin
        if (!rst_n | rx_read) begin
            state		<= IDLE;
            rx_data		<= 0;
        end else begin
			if (~state) begin
				state     <= ~rx_pin;
			end else if (state) begin
				if (bit_timer == 0) begin
					rx_data    <= {rx_pin, rx_data[9:1]};
					// if we have more bits increment the index and loop
					if (bit_index == 9) begin
						state     <= IDLE;								// otherwise transition to waiting for the STOP bit
					end 
				end 
			end
		end
	end

    always @(posedge clk) begin
		if (~state) begin
			bit_timer <= (baud_div >> 1); 	// wait half for a LOW START pulse
			bit_index <= 0;
		end else if (state) begin
			if (bit_timer == 0) begin
				bit_timer  <= baud_div;								// reset the timer
				// if we have more bits increment the index and loop
				if (bit_index == 9) begin
					bit_index <= 0;
				end else begin
					bit_index <= bit_index + 1'b1;
				end
			end else begin
				bit_timer <= bit_timer - 1'b1;
			end
		end
	end
endmodule
