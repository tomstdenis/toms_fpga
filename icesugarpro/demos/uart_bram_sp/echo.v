`timescale 1ns/1ps

/* Demo program that uses a single 2048x8 semi-dual port memory

This demos syncs on a 0x5A byte, then reads 2048 bytes at 115.2K, then writes them back.

The test loops back to the sync byte.

*/

module top(
	input clk,
	input rx,
	output tx);
	
	wire [15:0] bauddiv = (`FREQ * 1_000_000) / 115_200;
	reg uart_tx_start;
	reg uart_rx_read;
	reg [7:0] uart_tx_data_in;
	wire uart_rx_ready;
	wire [7:0] uart_rx_byte;
	wire uart_tx_fifo_full;
	wire pll_clk;
	wire plllock;
	reg [3:0] rst = 0;
	wire rst_n = rst[3];
	
	pll mypll(.clkin(clk), .clkout0(pll_clk), .locked(plllock));

	always @(posedge pll_clk) begin
		if (plllock) begin
			rst <= {rst[2:0], 1'b1};
		end
	end
		
	uart #(.FIFO_DEPTH(4), .RX_ENABLE(1), .TX_ENABLE(1)) myuart(
		.clk(pll_clk), .rst_n(rst_n),
		.baud_div(bauddiv), 
		.uart_tx_start(uart_tx_start), .uart_tx_data_in(uart_tx_data_in), .uart_tx_pin(tx), .uart_tx_fifo_full(uart_tx_fifo_full),
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
	reg [3:0] init;

	always @(posedge pll_clk) begin
		if (!rst_n) begin
			state 		<= 0;
			bram_w_addr <= 0;
			bram_r_addr <= 0;
			bram_w_en   <= 0;
			init  		<= 0;
			uart_tx_start <= 0;
			uart_rx_read <= 0;
		end else begin
			case(state)
				0:													// wait for byte on uart
					begin
						uart_tx_start	 <= 0;
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
						if (init != 4) begin							// flush RX bytes until we get 5A
							if (uart_rx_byte == (8'h5A + init)) begin
								init <= init + 1;					// we're in the init state
							end else begin
								init <= 0;
							end
							bram_w_addr	<= 0;						// ensure we're at byte 0
							state		<= 0;						// wait for next byte
						end else begin
							bram_w_en 	<= 1;						// write byte 
							bram_w_data <= uart_rx_byte;			// we're writing the byte from the UART rx 
							state		<= state + 1;
						end
					end
				3:													// advance write pointer and stop writing
					begin
						bram_w_en		<= 0;						// stop writing
						bram_w_addr 	<= bram_w_addr + 1;			// advance write address to next address
						if (bram_w_addr == 11'h7FF) begin
							state		<= 4;						// Switch to reading back since we hit the top of memory
							bram_w_addr <= 0;						// ensure the write address is reset
						end else begin
							state		<= 0;						// we're not at the top of memory so go back and read the next from the UART
						end
					end
				4:													// delay for read to fetch byte written in previous cycle
					begin
						state			<= state + 1;
						uart_tx_start	<= 0;						// ensure we're not transmitting on the UART
					end
				5:													// transmit the byte read from bram
					begin
						if (!uart_tx_fifo_full) begin				// only transmit if the FIFO is not full
							uart_tx_data_in <= bram_r_data;			// read from memory
							uart_tx_start	<= 1;					// transmit
							bram_r_addr		<= bram_r_addr + 1;		// advance read address
							if (bram_r_addr == 11'h7FF) begin
								state			<= 0;				// done reading back memory
								bram_r_addr		<= 0;				// ensure read address is zero'ed
								init			<= 0;				// go back to waiting for sync byte
							end else begin
								state			<= 4;				// go to next byte to write
							end
						end
					end
				default: state <= 0;
			endcase
		end
	end
endmodule
