`timescale 1ns/1ps

module top(
	input clk,
	input rx,
	output tx);

	reg rst_n;
	wire [15:0] bauddiv = 12_000_000 / 115_200;
	reg uart_tx_start;
	reg uart_rx_read;
	reg [7:0] uart_tx_data_in;
	wire uart_rx_ready;
	wire [7:0] uart_rx_byte;
	
	initial begin
		rst_n = 0;
	end
	
	uart #(.FIFO_DEPTH(32), .RX_ENABLE(1), .TX_ENABLE(1)) myuart(
		.clk(clk), .rst_n(rst_n),
		.baud_div(bauddiv), 
		.uart_tx_start(uart_tx_start), .uart_tx_data_in(uart_tx_data_in), .uart_tx_pin(tx),
		.uart_rx_pin(rx), .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready), .uart_rx_byte(uart_rx_byte));
	
	always @(posedge clk) begin
		if (!rst_n) begin
			rst_n <= 1;
		end else begin
			if (uart_rx_ready) begin
				uart_rx_read <= 1;
				uart_tx_data_in <= uart_rx_byte;
				uart_tx_start <= 1;
			end else begin
				uart_rx_read <= 0;
				uart_tx_start <= 0;
			end
		end
	end
endmodule
