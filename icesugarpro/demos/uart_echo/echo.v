`timescale 1ns/1ps

module top(
	input clk,
	input rx,
	output tx);
	
//`define LOOPBACK
`ifdef LOOPBACK
	assign tx = rx;
`else
	reg rst_n;
	wire [15:0] bauddiv = 250_000_000 / 1_000_000;
	reg uart_tx_start;
	reg uart_rx_read;
	reg [7:0] uart_tx_data_in;
	wire uart_rx_ready;
	wire [7:0] uart_rx_byte;
	wire pll_clk;
	wire plllock;
	
	initial begin
		rst_n = 0;
	end
	
	pll mypll(.clkin(clk), .clkout0(pll_clk), .locked(plllock));
		
	uart #(.FIFO_DEPTH(4), .RX_ENABLE(1), .TX_ENABLE(1)) myuart(
		.clk(pll_clk), .rst_n(rst_n),
		.baud_div(bauddiv), 
		.uart_tx_start(uart_tx_start), .uart_tx_data_in(uart_tx_data_in), .uart_tx_pin(tx),
		.uart_rx_pin(rx), .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready), .uart_rx_byte(uart_rx_byte));

	reg [3:0] state;
	
	always @(posedge pll_clk) begin
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

	always @(posedge pll_clk) begin
		uart_tx_data_in <= uart_rx_byte;
	end
`endif
endmodule
