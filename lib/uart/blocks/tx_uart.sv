`timescale 1ns/1ps
`default_nettype none

// Serial 8N1 transmitter with variable baudrate
module tx_uart
(
    input logic clk,                          
    input logic rst_n,                        // active low reset
    input logic [15:0] baud_div,              // counter value for baud calculation (e.g. F_CLK/BAUD == baud_div)
    input logic start_tx,                     // active high start transmitting whatever is in data_in (which is latched after the first cycle)
    input logic [7:0] data_in,
    output logic tx_pin,                  // (out) the TX pin
    output logic tx_started,              // (out) Indicates transmission started
    output logic tx_done                  // (out) indicates TX done
);
    localparam
        IDLE      = 0, // waiting for a byte
        START_BIT = 1, // parsing START bit
        DATA_BITS = 2, // reading in data bits
        STOP_BIT  = 3; // parsing STOP bit waiting to go to IDLE

    logic [1:0] state;
    logic [15:0] bit_timer;
    logic [2:0] bit_index;
    logic [7:0] data_latch;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state 		<= IDLE;
            tx_pin 		<= 1'b1;
            tx_done 	<= 1'b1;
            tx_started 	<= 0;
            data_latch 	<= 0;
            bit_timer 	<= 0;
            bit_index 	<= 0;
        end else begin
            case (state)
                IDLE: begin									// IDLE state waiting for start_tx to go high
                    tx_pin <= 1'b1; 						// UART idle is HIGH
                    if (start_tx) begin
                        data_latch <= data_in;				// latch the data being transmitted
                        bit_timer  <= baud_div;				// and the current baud_div
                        bit_index  <= 0;
                        state      <= START_BIT;
                        tx_started <= 1'b1;
                        tx_done    <= 1'b0;
                    end
                end

                START_BIT: begin							// transmit the START bit which is a pulse of LOW
                    tx_pin <= 1'b0;							// Pull low for START
                    if (bit_timer == 0) begin
                        bit_timer <= baud_div;
                        state     <= DATA_BITS;
                    end else begin
                        bit_timer <= bit_timer - 1'b1;
                    end
                end

                DATA_BITS: begin							// Send data bits as pulse width signals
                    tx_pin <= data_latch[bit_index]; 		// Send current bit
                    if (bit_timer == 0) begin
                        bit_timer <= baud_div;
                        if (bit_index == 7) begin
                            state <= STOP_BIT;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        bit_timer <= bit_timer - 1'b1;
                    end
                end

                STOP_BIT: begin								// Send STOP bit which is a pulse of HIGH
                    tx_pin <= 1'b1;							// Pull high for STOP
                    if (bit_timer == 0) begin
                        tx_done		<= 1'b1;
                        tx_started	<= 1'b0;
                        state		<= IDLE;
                    end else begin
                        bit_timer <= bit_timer - 1'b1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
