`timescale 1ns/1ps
`default_nettype none

module top(
	input clk,
	input rx,
	output tx);
	
	reg rst_n;

	localparam
		freq = 100_000_000,
		baud = 1_000_000,
		baudwidth = $clog2(freq / baud);
		
	wire [baudwidth-1:0] bauddiv = freq / baud;
	reg uart_tx_start;
	reg uart_rx_read;
	reg [7:0] uart_tx_data_in;
	wire uart_tx_fifo_full;
	wire uart_rx_ready;
	wire [7:0] uart_rx_byte;
	wire pll_clk;
	wire plllock;

	initial begin
		rst_n = 0;
	end

	pll mypll(.clkin(clk), .clkout0(pll_clk), .locked(plllock));
		
	uart #(.BAUD_WIDTH(baudwidth), .FIFO_DEPTH(4), .RX_ENABLE(0), .TX_ENABLE(1)) myuart(
		.clk(pll_clk), .rst_n(rst_n),
		.baud_div(bauddiv), 
		.uart_tx_start(uart_tx_start), .uart_tx_data_in(uart_tx_data_in), .uart_tx_pin(tx), .uart_tx_fifo_full(uart_tx_fifo_full),
		.uart_rx_pin(rx), .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready), .uart_rx_byte(uart_rx_byte));

	wire osc_bit;
	wire osc_strobe;
	
	osc_rng funnybits (.clk(pll_clk), .rst_n(rst_n), .bit(osc_bit), .strobe(osc_strobe));

	reg bit_l;
	reg strobe_l;

	always @(posedge pll_clk) begin
		strobe_l      <= strobe_l | osc_strobe;
		uart_tx_start <= 1'b0;
		uart_rx_read  <= 1'b0;
		
		if (osc_strobe) begin
			bit_l <= osc_bit;
		end

		if (strobe_l && !uart_tx_fifo_full) begin
			strobe_l        <= 1'b0;
			uart_tx_data_in <= uart_tx_data_in ^ bit_l;
			uart_tx_start   <= 1'b1;
		end

		if (!rst_n) begin
			rst_n           <= 1;
			strobe_l        <= 1'b0;
			bit_l           <= 1'b0;
			uart_tx_data_in <= 8'd64;
		end
	end
endmodule
