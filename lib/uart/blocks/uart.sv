`timescale 1ns/1ps
`default_nettype none

// This implements a UART block which is full or half duplex (RX or TX or both)
// with a variable sized FIFO and programmable baud rate
// uses 8N1 signalling
module uart#(parameter FIFO_DEPTH=64, RX_ENABLE=1, TX_ENABLE=1)
(
    input logic clk,                      // main clock
    input logic rst_n,                    // active low reset
    input logic [15:0] baud_div,          // counter value for baud calculation (e.g. F_CLK/BAUD == baud_div)
    input logic uart_tx_start,            // signal we want to load uart_tx_data_in into the TX FIFO
    input logic [7:0] uart_tx_data_in,    // TX data
    output logic uart_tx_pin,             // (out) pin for transmitting on
    output logic uart_tx_fifo_full,       // (out) true if the FIFO is currently full
    output logic uart_tx_fifo_empty,      // (out) true if the FIFO is empty

    input logic uart_rx_pin,              // pin to RX from
    input logic uart_rx_read,             // signal that we read a byte
    output logic uart_rx_ready,       // (out) signal that an output byte is available
    output logic [7:0] uart_rx_byte   // (out) the RX byte
);
    // note: things starting with uart_ are input/outputs to this module (other than clk)
    generate
        if (TX_ENABLE) begin : tx_gen
            // local TX state 
            logic [7:0] tx_fifo[FIFO_DEPTH-1:0];
            logic [7:0] tx_send;
            logic tx_start;
            logic tx_done;
            logic tx_started;
            logic [$clog2(FIFO_DEPTH)-1:0] tx_fifo_wptr;
            logic [$clog2(FIFO_DEPTH)-1:0] tx_fifo_rptr;
            logic [$clog2(FIFO_DEPTH):0] tx_fifo_cnt;

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
            assign uart_tx_fifo_full = (tx_fifo_cnt == (FIFO_DEPTH));
            assign uart_tx_fifo_empty = (tx_fifo_cnt == 0);

            always_ff @(posedge clk) begin
                if (!rst_n) begin
					tx_send 		<= 0;
                    tx_start 		<= 0;
                    tx_fifo_wptr 	<= 0;
                    tx_fifo_rptr 	<= 0;
                    tx_fifo_cnt 	<= 0;
                end else begin
                    // ===== TX =====
					// Store a new byte on uart_tx_start asserted if the fifo isn't full
                    if (uart_tx_start && !uart_tx_fifo_full) begin
                        // user wants to transmit a byte and the fifo isn't full so store it in the fifo
                        tx_fifo[tx_fifo_wptr]	<= uart_tx_data_in;
                        tx_fifo_wptr 			<= tx_fifo_wptr + 1'd1;
                        tx_fifo_cnt				<= tx_fifo_cnt + 1'd1;
						if (tx_started) begin
							tx_start			<= 1'b0;					// transmit started, deassert tx_start
						end
                    end else if (!tx_start && tx_done && (tx_fifo_cnt > 0)) begin
						// send a new byte to the uart_tx if uart_tx is idle (done==1), rptr != wptr, we didn't start a byte recently or the 
                        tx_send			<= tx_fifo[tx_fifo_rptr]; 
                        tx_fifo_rptr	<= tx_fifo_rptr + 1'd1;
                        tx_start		<= 1'b1;						// we read a byte out of the fifo to transmit 
                        tx_fifo_cnt		<= tx_fifo_cnt - 1'd1;
                    end else begin
						tx_start		<= 1'b0;						// if we're idle ensure we're not asserting tx start
					end
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
            logic [7:0] rx_fifo[FIFO_DEPTH-1:0];
            logic [$clog2(FIFO_DEPTH)-1:0] rx_fifo_wptr;
            logic [$clog2(FIFO_DEPTH)-1:0] rx_fifo_rptr;
            logic [$clog2(FIFO_DEPTH):0] rx_fifo_cnt;
            logic rx_read;
            logic rx_done;
            logic [7:0] rx_byte;
            logic [1:0] rx_sync_pipe;
            logic prev_uart_rx_read;

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

            always_ff @(posedge clk) begin
                if (!rst_n) begin
                    rx_read				<= 0;
                    rx_fifo_wptr		<= 0;
                    rx_fifo_rptr		<= 0;
                    rx_fifo_cnt			<= 0;
                    uart_rx_byte		<= 0;
                    prev_uart_rx_read 	<= 0;
                    uart_rx_ready 		<= 0;
                    rx_sync_pipe 		<= 2'b11;
                end else begin
                    // ===== RX =====
                    rx_sync_pipe	<= {rx_sync_pipe[0], uart_rx_pin};
                    uart_rx_ready	<= rx_fifo_cnt > 0 ? 1'b1 : 1'b0;
                    // if the user wants something from the fifo and there is a byte advance the read pointer
                    if (uart_rx_read && (rx_fifo_cnt > 0)) begin
                        // note the output is combinatorial above ...
                        uart_rx_byte	<= rx_fifo[rx_fifo_rptr];
                        rx_fifo_rptr	<= rx_fifo_rptr + 1'd1;
                        rx_fifo_cnt		<= rx_fifo_cnt - 1'd1;
                        rx_read			<= 0; // ensure we release the read strobe
                    end else if (rx_done && !rx_read) begin
						// if an RX finished store it in the fifo if room and then acknowledge the read
                        // read a byte if we have room
                        if (rx_fifo_cnt != FIFO_DEPTH) begin
                            rx_fifo[rx_fifo_wptr]	<= rx_byte;
                            rx_fifo_wptr			<= rx_fifo_wptr + 1'd1;
                            rx_fifo_cnt				<= rx_fifo_cnt + 1'd1;
                        end
						rx_read <= 1; // discard bytes that overflow the device
                    end else begin
                        // clear the read acknowledgement
                        if (!rx_done) begin
                            rx_read <= 0;
                        end
                    end
                end
            end
        end else begin : rx_stub
            always @(posedge clk) begin
                uart_rx_ready	<= 1'b0;
                uart_rx_byte	<= 8'h00;
            end
        end
    endgenerate
endmodule
