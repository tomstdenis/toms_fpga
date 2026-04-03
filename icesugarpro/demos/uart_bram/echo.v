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
	wire [15:0] bauddiv = (`FREQ * 1_000_000) / 115_200;
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

	reg [10:0] bram_w_addr;
	reg [7:0] bram_w_data;
	reg bram_w_en;
	reg [10:0] bram_r_addr;
	wire [7:0] bram_r_data;

	bram_sp_2048x8 bram(
		.w_clk(pll_clk),					// write clock
		.w_clk_en(1'b1),					// write clock enable
		.w_rst(~rst_n),						// write active high reset
		.w_addr(bram_w_addr),				// write address
		.w_data(bram_w_data),				// write data
		.w_en(bram_w_en),					// write enable

		.r_clk(pll_clk),					// read clock
		.r_clk_en(1'b1),					// read clock enable
		.r_rst(~rst_n),						// read active high reset
		.r_addr(bram_r_addr),				// read address
		.r_data(bram_r_data));				// read data


	reg [3:0] state;

	always @(posedge pll_clk) begin
		if (!rst_n) begin
			rst_n <= 1;
			state <= 0;
			bram_w_addr <= 0;
			bram_r_addr <= 0;
			bram_w_en   <= 0;
		end else begin
			case(state)
				0:													// wait for byte on uart
					begin
						if (uart_rx_ready) begin
							// there's a byte to read
							uart_rx_read <= 1'b1;
							state        <= state + 1;
						end
					end
				1:													// delay cycle for uart
					begin
						// waiting for read to ack byte
						uart_rx_read <= 1'b0;						// only want 1 byte from the RX fifo
						state		 <= state + 1;					// next cycle we'll have the byte
					end
				2:													// write uart byte to bram
					begin
						bram_w_en 	<= 1;							// write byte 
						bram_w_data <= uart_rx_byte;
						state		<= state + 1;
					end
				3:													// advance write pointer and stop writing
					begin
						bram_w_en	<= 0;							// stop writing, since r_addr == w_addr already we just wait this cycle to read it
						bram_w_addr <= bram_w_addr + 1;
						state		<= state + 1;
					end
				4:													// delay for read to fetch byte written in previous cycle
					begin
						state		<= state + 1;
					end
				5:													// transmit the byte read from bram
					begin
						uart_tx_data_in <= bram_r_data;				// read from memory
						uart_tx_start	<= 1;						// transmit
						bram_r_addr		<= bram_r_addr + 1;
						state			<= state + 1;
					end
				6:													// stop transmitting and start loop over
					begin
						uart_tx_start	<= 0;
						state			<= 0;
					end
			endcase
		end
	end
`endif
endmodule
