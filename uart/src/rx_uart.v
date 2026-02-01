// Serial 8N1 receive with variable baudrate
module rx_uart
(
    input clk,                          
    input rst,                          // active low reset
    input [15:0] baud_div,              // counter value for baud calculation (e.g. F_CLK/BAUD == baud_div)
    input rx_pin,                       // UART assigned pin
    input rx_read,                      // active high indicates when you read the byte to clear the rx_done pin
    output reg rx_done,                 // (out) indicates a character is ready
    output reg [7:0] rx_byte            // (out) the character that was read
);
    localparam
        IDLE      = 0, // waiting for a byte
        START_BIT = 1, // parsing START bit
        DATA_BITS = 2, // reading in data bits
        STOP_BIT  = 3; // parsing STOP bit waiting to go to IDLE

    reg [1:0] state;
    reg [15:0] bit_timer;
    reg [2:0] bit_index;

    always @(posedge clk) begin
        if (!rst) begin
            state <= IDLE;
            rx_done <= 1'b0;
            bit_timer <= 0;
            bit_index <= 0;
        end else begin
            if (rx_read) begin
                // clear done flag since we read the byte
                rx_done <= 0;
            end
            case (state)
                // IDLE waiting or a low pulse.  
                IDLE: begin
                    if (~rx_pin) begin              // going low is the start of a byte
                        state <= START_BIT;
                        bit_timer <= (baud_div >> 1);  // wait half for a LOW START pulse
                        bit_index <= 0;
                        rx_byte <= 0;
                    end
                end

                START_BIT: begin
                    if (bit_timer == 0) begin
                        if (~rx_pin) begin // Verify it's still low (avoid glitches)
                            state <= DATA_BITS;
                            bit_timer <= baud_div;
                            bit_index <= 0;
                            rx_byte <= 0;
                        end else state <= IDLE;
                    end else bit_timer <= bit_timer - 1'b1;
                end

                // read the 8 data bits
                DATA_BITS: begin
                    if (!bit_timer) begin
                        // store the next bit
                        rx_byte[bit_index] <= rx_pin;
                        // reset the timer
                        bit_timer <= baud_div;
                        // if we have more bits increment the index and loop
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                        // otherwise transition to waiting for the STOP bit
                            state <= STOP_BIT;
                        end
                    end else begin
                        bit_timer <= bit_timer - 1'b1;
                    end
                end

                // wait for the STOP bit, note we don't check if it's low...
                STOP_BIT: begin
                    if (!bit_timer) begin
                        rx_done <= 1'b1;
                        state <= IDLE;
                    end else begin
                        bit_timer <= bit_timer - 1'b1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
