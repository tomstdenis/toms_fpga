`timescale 1ns/1ps
/*

	Simple serial debugger - UART bridge
	
This module accepts SF_BITS sized packets from the UART RX, sends it over the serial debug wire, and then transmits
what it receives on the other side via the UART TX.

*/

module serial_debug_uart #(
	parameter BITS=128
)(
	input clk,
	input rst_n,
	
	// baud rate
	input [7:0] prescaler,								// prescaler against clk to control tx_clk (ideally >= 2) (meant to be a constant wire not subject to reset)
	
	// serial input
	input debug_tx_data,								// incoming debug serial data (from the last debug node)
	input debug_tx_clk,									// incoming debug serial clock
	
	// serial output
	output reg debug_rx_data,							// outgoing debug serial data (to the first debug node)
	output reg debug_rx_clk,							// outgoing debug serial clock
	
	// uart
	input [15:0] uart_bauddiv,
	input uart_rx_pin,
	output uart_tx_pin
);

	reg uart_tx_start;
	reg [7:0] uart_tx_data_in;
	wire uart_tx_fifo_full;
	reg  uart_rx_read;
	wire uart_rx_ready;
	wire [7:0] uart_rx_byte;

	uart #(.FIFO_DEPTH(8), .RX_ENABLE(1), .TX_ENABLE(1)) debug_uart
		(
			.clk(clk), .rst_n(rst_n),
			.baud_div(uart_bauddiv),
			.uart_tx_start(uart_tx_start), .uart_tx_data_in(uart_tx_data_in), .uart_tx_pin(uart_tx_pin), .uart_tx_fifo_full(uart_tx_fifo_full), .uart_tx_fifo_empty(),
			.uart_rx_pin(uart_rx_pin), .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready), .uart_rx_byte(uart_rx_byte)
		);

	localparam
		SF_BITS = BITS + 16;								// bits per store-forward frame, 128 data bits + 15 address bits + 1 direction bit

	reg [SF_BITS-1:0] uart_buf;
	reg [7:0] uart_buf_i;
	reg [3:0] uart_state;
	reg [3:0] uart_tag;
	reg [7:0] prescale_cnt;
	reg [3:0] tx_data_pipe;								// sync pipe for rx_data
	reg [3:0] tx_clk_pipe;								// sync pipe for rx_clk
	wire cur_tx_data = tx_data_pipe[2];					// current synced data
	wire cur_tx_clk  = tx_clk_pipe[2];					// current synced clock
	wire cur_tx_clk_prev = tx_clk_pipe[3];				// previous current synced clock

	localparam
		STATE_IDLE 				= 0,
		STATE_RX_LOOP			= 1,
		STATE_RX_LOOP_GETBYTE 	= 2,
		STATE_DBG_TX_LOOP		= 3,
		STATE_DBG_RX_LOOP		= 4,
		STATE_TX_LOOP			= 5,
		STATE_DELAY         	= 6;
		
	always @(posedge clk) begin
		if (!rst_n) begin
			uart_tx_start 		<= 0;
			uart_tx_data_in		<= 0;
			uart_rx_read		<= 0;
			uart_buf			<= 0;
			uart_buf_i			<= 0;
			uart_state			<= STATE_IDLE;
			debug_rx_clk		<= 1'b1;
			debug_rx_data		<= 0;
		end else begin
			// solve for metastability
			tx_data_pipe <= {tx_data_pipe[2:0], debug_tx_data};
			tx_clk_pipe  <= {tx_clk_pipe[2:0], debug_tx_clk};
			case(uart_state)
				STATE_DELAY:										// delay cycle to allow UART to respond to command
					begin
						uart_state		<= uart_tag;
						uart_rx_read	<= 0;						// disable RX/TX command 
						uart_tx_start	<= 0;
					end
				STATE_IDLE:
					begin
						uart_buf_i		<= SF_BITS/8;				// we expect to read SF_BITS/8 bytes
						if (uart_rx_ready) begin					// are there incoming bytes?
							uart_tag 	<= STATE_RX_LOOP_GETBYTE;	// head into RX loop
							uart_state  <= STATE_DELAY;
						end
					end
				STATE_RX_LOOP_GETBYTE:								// store a UART incoming byte and advance state
					begin
						uart_buf <= {uart_buf[SF_BITS-9:0], uart_rx_byte};
						if (uart_buf_i == 0) begin
							uart_state		<= STATE_DBG_TX_LOOP;
							uart_buf_i		<= SF_BITS;
							prescale_cnt	<= prescaler;
							debug_rx_clk    <= 1'b1;			// clock starts high
						end else begin
							uart_buf_i		<= uart_buf_i - 1'b1;
							uart_state 		<= STATE_RX_LOOP;
						end
					end
				STATE_RX_LOOP:										// read the store forward buffer 8 bits at a time from the UART
					begin
						if (uart_rx_ready) begin					// wait for an RX byte to be ready
							uart_rx_read 		<= 1;
							uart_state			<= STATE_DELAY;
							uart_tag			<= STATE_RX_LOOP_GETBYTE;
						end
					end
				STATE_DBG_TX_LOOP:									// transmit the entire store_forward
					begin
						if (prescale_cnt == 1) begin
							if (debug_rx_clk == 1) begin
								// we're going low so store the next bit
								debug_rx_data	<= uart_buf[SF_BITS-1];
								uart_buf		<= {uart_buf[SF_BITS-2:0], 1'b0 };
								if (uart_buf_i == 0) begin
									// we're done
									uart_state 	<= STATE_DBG_RX_LOOP;
									uart_buf_i  <= SF_BITS;
								end else begin
									// next bit (and we only set clock low if there is a next bit)
									uart_buf_i	<= uart_buf_i - 1'b1;
									debug_rx_clk <= 1'b0;
								end
							end else begin
								// we're going high so keep data steady
								debug_rx_clk 	<= 1'b1;
							end
							prescale_cnt		<= prescaler;
						end else begin
							prescale_cnt		<= prescale_cnt - 1'b1;
						end
					end
				STATE_DBG_RX_LOOP:									// receive the entire store forward
					begin
						if (cur_tx_clk_prev == 1'b0 && cur_tx_clk == 1'b1) begin	// detect raising edge of clock
							uart_buf <= {uart_buf[SF_BITS-2:0], cur_tx_data};
							if (uart_buf_i == 1) begin
								// we're done
								uart_buf_i <= SF_BITS/8;
								uart_state <= STATE_TX_LOOP;
							end else begin
								uart_buf_i <= uart_buf_i - 1'b1;
							end
						end
					end
				STATE_TX_LOOP:										// transmit the store forward over UART
					begin
						if (!uart_tx_fifo_full) begin
							uart_tx_data_in <= uart_buf[SF_BITS-1:SF_BITS-8];
							uart_buf 		<= {uart_buf[SF_BITS-9:0], 8'b0};
							uart_tx_start   <= 1;
							uart_tag		<= (uart_buf_i == 1) ? STATE_IDLE : STATE_TX_LOOP;
							uart_state		<= STATE_DELAY;
							uart_buf_i		<= uart_buf_i - 1'b1;
						end
					end
				default:
					begin
					end
			endcase
		end
	end
endmodule
