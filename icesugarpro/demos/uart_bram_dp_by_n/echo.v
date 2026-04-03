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

	localparam
		STRIDE = (2048 * `BLOCKS) - 1;

	reg [10+$clog2(`BLOCKS):0] bram_addr_a;
	reg [7:0] bram_din_a;
	reg bram_we_a;
	wire [7:0] bram_dout_a;
	
	reg [10+$clog2(`BLOCKS):0] bram_addr_b;
	reg [7:0] bram_din_b;
	reg bram_we_b;
	wire [7:0] bram_dout_b;

	bram_dp_nx2048x8 #(.N(`BLOCKS)) bram (
		.clk_a(pll_clk),
		.clk_en_a(1'b1),
		.rst_a(~rst_n),
		.addr_a(bram_addr_a),
		.din_a(bram_din_a),
		.we_a(bram_we_a),
		.dout_a(bram_dout_a),
		
		.clk_b(pll_clk),
		.clk_en_b(1'b1),
		.rst_b(~rst_n),
		.addr_b(bram_addr_b),
		.din_b(bram_din_b),
		.we_b(bram_we_b),
		.dout_b(bram_dout_b),
	);
	
	reg [3:0] state;
	reg [3:0] init;
	reg [1:0] test_count;

	always @(posedge pll_clk) begin
		if (!rst_n) begin
			state 		  <= 0;
			init  		  <= 0;
			bram_addr_a   <= 0;
			bram_addr_b   <= 0;
			bram_din_a    <= 0;
			bram_din_b    <= 0;
			bram_we_a     <= 0;
			bram_we_b     <= 0;
			uart_rx_read  <= 0;
			uart_tx_start <= 0;
			uart_tx_data_in <= 0;
			test_count	  <= 0;
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
						if (init != 4) begin							// flush RX bytes until we get 5A 5B 5C 5D
							if (uart_rx_byte == (8'h5A + init)) begin
								init <= init + 1;					// we're in the init state
							end else begin
								init <= 0;							// not a sync byte so reset count
							end
							bram_addr_a	<= 0;						// ensure we're at byte 0
							bram_addr_b	<= 0;						// ensure we're at byte 0
							state		<= 0;						// wait for next byte
						end else begin
							if (test_count[0]) begin
								bram_we_a 	<= 1;					// write byte using port A
							end else begin
								bram_we_b	<= 1;					// write byte using port B
							end
							bram_din_a  <= uart_rx_byte;			// we're writing the byte from the UART rx 
							bram_din_b  <= uart_rx_byte;			// we're writing the byte from the UART rx 
							state		<= state + 1;
						end
					end
				3:													// advance write pointer and stop writing
					begin
						bram_we_a		<= 0;
						bram_we_b		<= 0;
						bram_addr_a 	<= bram_addr_a + 1;			// advance write address to next address
						bram_addr_b 	<= bram_addr_b + 1;			// advance write address to next address
						if (bram_addr_a == STRIDE) begin
							state		<= 4;						// Switch to reading back since we hit the top of memory
							bram_addr_a <= 0;						// ensure the write address is reset
							bram_addr_b <= 0;						// ensure the write address is reset
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
							if (test_count[1]) begin
								uart_tx_data_in <= bram_dout_a;
							end else begin
								uart_tx_data_in <= bram_dout_b;			// read from memory
							end
							uart_tx_start	<= 1;					// transmit
							bram_addr_a 	<= bram_addr_a + 1;			// advance write address to next address
							bram_addr_b 	<= bram_addr_b + 1;			// advance write address to next address
							if (bram_addr_a == STRIDE) begin
								state			<= 0;				// done reading back memory
								bram_addr_a		<= 0;				// ensure read address is zero'ed
								bram_addr_b		<= 0;				// ensure read address is zero'ed
								init			<= 0;				// go back to waiting for sync byte
								test_count		<= test_count + 1'b1;
							end else begin
								state			<= 4;				// go to next byte to write
							end
						end
					end
				default: begin end
			endcase
		end
	end
endmodule
