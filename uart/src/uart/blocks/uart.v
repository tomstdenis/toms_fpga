`timescale 1ns/1ps

// This implements a UART block which is full or half duplex (RX or TX or both)
// with a variable sized FIFO and programmable baud rate
// uses 8N1 signalling
module uart#(parameter FIFO_DEPTH=64, RX_ENABLE=1, TX_ENABLE=1)
(
    input clk,                      // main clock
    input rst_n,                      // active low reset
    input [15:0] baud_div,          // counter value for baud calculation (e.g. F_CLK/BAUD == baud_div)
    input uart_tx_start,            // (edge triggered) signal we want to load uart_tx_data_in into the TX FIFO
    input [7:0] uart_tx_data_in,    // TX data
    output uart_tx_pin,             // (out) pin for transmitting on
    output uart_tx_fifo_full,       // (out) true if the FIFO is currently full
    output uart_tx_fifo_empty,      // (out) true if the FIFO is empty

    input uart_rx_pin,              // pin to RX from
    input uart_rx_read,             // (edge triggered)  signal that we read a byte
    output reg uart_rx_ready,       // (out) signal that an output byte is available
    output reg [7:0] uart_rx_byte       // (out) the RX byte
);
    // note: things starting with uart_ are input/outputs to this module (other than clk)
    generate
        if (TX_ENABLE) begin : tx_gen
            // local TX state 
            reg [7:0] tx_fifo[FIFO_DEPTH-1:0];
            reg [7:0] tx_send;
            reg tx_start;
            wire tx_done;
            wire tx_started;
            reg [$clog2(FIFO_DEPTH)-1:0] tx_fifo_wptr;
            reg [$clog2(FIFO_DEPTH)-1:0] tx_fifo_rptr;
            reg [$clog2(FIFO_DEPTH):0] tx_fifo_cnt;

            // instantiate a transmitter
            tx_uart txuart (
                .clk(clk),
                .rst_n(rst_n),
                .baud_div(baud_div),
                .start_tx(tx_start), 
                .data_in(tx_send), 
                .tx_pin(uart_tx_pin), 
                .tx_started(tx_started), 
                .tx_done(tx_done)
            );

            // Output signals are combinatorial
            assign uart_tx_fifo_full = (tx_fifo_cnt == (FIFO_DEPTH - 1));
            assign uart_tx_fifo_empty = (tx_fifo_cnt == 0);
            reg prev_uart_tx_start;

            always @(posedge clk) begin
                if (!rst_n) begin
					tx_send <= 0;
                    tx_start <= 0;
                    tx_fifo_wptr <= 0;
                    tx_fifo_rptr <= 0;
                    tx_fifo_cnt <= 0;
                    prev_uart_tx_start <= 0;
                end else begin
                    // ===== TX =====
					// Store a new byte on the posedge of uart_tx_start if the fifo isn't full
                    if (uart_tx_start != prev_uart_tx_start && !uart_tx_fifo_full) begin
                        // user wants to transmit a byte and the fifo isn't full so store it in the fifo
                        tx_fifo[tx_fifo_wptr] <= uart_tx_data_in;
                        tx_fifo_wptr <= tx_fifo_wptr + 1'd1;
                        tx_fifo_cnt <= tx_fifo_cnt + 1'd1;
						tx_start <= 1'b0;
                    end else if (!tx_start && tx_done && (tx_fifo_wptr != tx_fifo_rptr)) begin
						// send a new byte to the uart_tx if uart_tx is idle (done==1), rptr != wptr, we didn't start a byte recently or the 
                        tx_send <= tx_fifo[tx_fifo_rptr]; 
                        tx_fifo_rptr <= tx_fifo_rptr + 1'd1;
                        tx_start <= 1'b1;
                        tx_fifo_cnt <= tx_fifo_cnt - 1'd1;
                    end else begin
						tx_start <= 1'b0;
					end
					prev_uart_tx_start <= uart_tx_start;
                end
            end
        end else begin :tx_stub
            assign uart_tx_pin = 1'b1;
            assign uart_tx_fifo_full = 1'b1;
        end
    endgenerate

    generate
        if (RX_ENABLE) begin : rx_gen
            // local RX state
            reg [7:0] rx_fifo[FIFO_DEPTH-1:0];
            reg [$clog2(FIFO_DEPTH)-1:0] rx_fifo_wptr;
            reg [$clog2(FIFO_DEPTH)-1:0] rx_fifo_rptr;
            reg rx_read;
            wire rx_done;
            wire [7:0] rx_byte;
            reg [1:0] rx_sync_pipe;
            reg prev_uart_rx_read;

            // instantiate the receiver
            rx_uart rxuart (
                .clk(clk),
                .rst_n(rst_n),
                .baud_div(baud_div),
                .rx_pin(rx_sync_pipe[1]), 
                .rx_read(rx_read), 
                .rx_done(rx_done), 
                .rx_byte(rx_byte)
            );

            always @(posedge clk) begin
                if (!rst_n) begin
                    rx_read <= 0;
                    rx_fifo_wptr <= 0;
                    rx_fifo_rptr <= 0;
                    uart_rx_byte <= 0;
                    prev_uart_rx_read <= 0;
                    uart_rx_ready <= 0;
                    rx_sync_pipe = 2'b11;
                end else begin
                    // ===== RX =====
                    rx_sync_pipe <= {rx_sync_pipe[0], uart_rx_pin};
                    uart_rx_ready <= (rx_fifo_wptr != rx_fifo_rptr);
                    prev_uart_rx_read <= uart_rx_read;
                    // if the user wants something from the fifo and there is a byte advance the read pointer
                    if (uart_rx_read != prev_uart_rx_read && rx_fifo_rptr != rx_fifo_wptr) begin
                        // note the output is combinatorial above ...
                        uart_rx_byte <= rx_fifo[rx_fifo_rptr];
                        rx_fifo_rptr <= rx_fifo_rptr + 1'd1;
                    end else if (rx_done && !rx_read) begin
						// if an RX finished store it in the fifo if room and then acknowledge the read
                        // read a byte if we have room
                        if ((rx_fifo_wptr + 1'd1) != rx_fifo_rptr) begin
                            rx_fifo[rx_fifo_wptr] <= rx_byte;
                            rx_fifo_wptr <= rx_fifo_wptr + 1'd1;
							rx_read <= 1;
                        end
                    end else begin
                        // clear the read acknowledgement
                        if (!rx_done) begin
                            rx_read <= 0;
                        end
                    end
                end
            end
        end else begin : rx_stub
            assign uart_rx_ready = 1'b0;
            assign uart_rx_byte = 8'h00;
        end
    endgenerate
endmodule
