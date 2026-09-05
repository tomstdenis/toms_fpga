`default_nettype none
`timescale 1ns/1ps

module top(
	input clk,
	input rx,
	output tx);
	
	reg rst_n;
	initial begin
		rst_n = 0;
	end

	localparam
		freq = 25_000_000,
		baud = 19_200,
		baudwidth = $clog2(freq / baud);

	
	reg [7:0] text_mem[0:2047];
	reg [7:0] text_out;
	reg [7:0] text_in;
	reg [11:0] text_addr;
	reg        text_wren;
	
	always @(posedge clk) begin
		if (text_wren) begin
			text_mem[text_addr] <= text_in;
		end
		text_out <= text_mem[text_addr];
	end
	
	initial begin
`include "text_mem.vh"	
	end
		
	wire [baudwidth-1:0] bauddiv = freq / baud;
	reg uart_tx_start;
	reg uart_rx_read;
	reg [7:0] uart_tx_data_in;
	wire uart_rx_ready;
	wire uart_tx_fifo_full;
	wire [7:0] uart_rx_byte;

	uart #(.BAUD_WIDTH(baudwidth), .FIFO_DEPTH(4), .RX_ENABLE(1), .TX_ENABLE(1)) myuart(
		.clk(clk), .rst_n(rst_n),
		.baud_div(bauddiv), 
		.uart_tx_start(uart_tx_start), .uart_tx_data_in(uart_tx_data_in), .uart_tx_pin(tx), .uart_tx_fifo_full(uart_tx_fifo_full),
		.uart_rx_pin(rx), .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready), .uart_rx_byte(uart_rx_byte));

	reg spin;

	always @(posedge clk) begin
		if (!rst_n) begin
			rst_n         <= 1;
			text_addr     <= 0;
			spin          <= 1'b1;
			uart_tx_start <= 1'b0;
		end else begin
			spin          <= 1'b0;
			uart_tx_start <= 1'b0;
			if (!spin && !uart_tx_fifo_full) begin 
				uart_tx_data_in <= text_out;
				uart_tx_start   <= 1'b1;
				text_addr       <= text_addr + 1'b1;
				spin            <= 1'b1;
			end
		end
	end
endmodule
