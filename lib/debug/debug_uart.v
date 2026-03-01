`timescale 1ns/1ps

/*

	Simple serial debugger - UART bridge
	
This module accepts SF_BITS sized packets from the UART RX, sends it over the serial debug wire, and then transmits
what it receives on the other side via the UART TX.


*/

module serial_debug_uart (
	input clk,
	input rst_n,
	
	// baud rate
	input [7:0] prescaler,								// prescaler against clk to control tx_clk (ideally >= 2) (meant to be a constant wire not subject to reset)
	
	// serial input
	input debug_tx_data,								// incoming debug serial data (from the last debug node)
	input debug_tx_clk,									// incoming debug serial clock
	
	// serial output
	output reg debug_rx_data,							// outgoing debug serial data
	output reg debug_rx_clk,							// outgoing debug serial clock
	
	// uart
	input [15:0] uart_bauddiv,
	input uart_rx_pin,
	output reg uart_tx_pin
);

	reg uart_tx_start;
	reg [7:0] uart_tx_data_in;
	wire uart_tx_fifo_full;
	reg  uart_rx_read;
	wire uart_rx_ready;
	wire [7:0] uart_rx_byte;

	uart #(.FIFO_DEPTH(32), .RX_ENABLE(1), .TX_ENABLE(1)) debug_uart
		(
			.clk(clk), .rst_n(rst_n),
			.baud_div(uart_bauddiv),
			.uart_tx_start(uart_tx_start), .uart_tx_data_in(uart_tx_data_in), .uart_tx_pin(uart_tx_pin), .uart_tx_fifo_full(uart_tx_fifo_full), .uart_tx_fifo_empty(),
			.uart_rx_pin(uart_rx_pin), .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready), .uart_rx_byte(uart_rx_byte)
		);

	localparam
		SF_BITS = 128 + 16;								// bits per store-forward frame, 128 data bits + 15 address bits + 1 direction bit

	reg [SF_BITS-1:0] uart_buf;
	reg [7:0] uart_buf_i;
	reg [3:0] uart_state;
	
	localparam
		STATE_IDLE 			= 0,
		STATE_RX_LOOP		= 1,
		START_DBG_TX_LOOP	= 2,
		START_DBG_RX_LOOP	= 3,
		START_TX_LOOP		= 4;
		
	always @(posedge clk) begin
		if (!rst_n) begin
			uart_tx_start <= 0;
			uart_tx_data_in <= 0;
			uart_rx_read <= 0;
			uart_buf <= 0;
			uart_buf_i <= 0;
			uart_state <= STATE_IDLE;
		end else begin
			case(uart_state)
				STATE_IDLE:
					begin
					end
				default:
					begin
					end
			endcase
		end
	end
endmodule
