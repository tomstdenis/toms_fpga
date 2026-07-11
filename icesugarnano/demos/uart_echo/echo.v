`default_nettype none
`timescale 1ns/1ps

module top(
	input clk,
	input rx,
	output tx,
	output led);
	
	reg rst_n;
	localparam
		baudwidth = $clog2(12_000_000 / 1_000_000);
	wire [baudwidth-1:0] bauddiv = 12_000_000 / 1_000_000;
	reg uart_tx_start;
	reg uart_rx_read;
	reg [7:0] uart_tx_data_in;
	wire uart_rx_ready;
	wire [7:0] uart_rx_byte;
	reg ledv;
	assign led = ledv;
	
	reg [23:0] counter;
	
	initial begin
		rst_n = 0;
	end
		
	uart #(.BAUD_WIDTH(baudwidth), .FIFO_DEPTH(4), .RX_ENABLE(1), .TX_ENABLE(1)) myuart(
		.clk(clk), .rst_n(rst_n),
		.baud_div(bauddiv), 
		.uart_tx_start(uart_tx_start), .uart_tx_data_in(uart_tx_data_in), .uart_tx_pin(tx),
		.uart_rx_pin(rx), .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready), .uart_rx_byte(uart_rx_byte));
	
	reg [3:0] state;
	
	always @(posedge clk) begin
		if (!rst_n) begin
			rst_n           <= 1;
			state           <= 1;
			uart_rx_read    <= 0;
			uart_tx_start   <= 0;
		end else begin
			uart_rx_read    <= uart_rx_ready;
			uart_tx_start   <= state[2];
			state           <= (state[0] & ~uart_rx_ready) ? state : {state[2:0], state[3]};
		end
	end

	always @(posedge clk) begin
		counter <= counter + 1'b1;
		ledv    <= counter[23];
		uart_tx_data_in <= uart_rx_byte;
	end
endmodule
