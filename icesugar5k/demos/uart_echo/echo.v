`timescale 1ns/1ps

module top(
	input clk,
	input rx,
	output tx);

	wire pll_clk;
	wire pll_lock;
	
	reg rst_n;
	wire [15:0] bauddiv = 48_000_000 / 115_200;
	reg uart_tx_start;
	reg uart_rx_read;
	reg [7:0] uart_tx_data_in;
	wire uart_rx_ready;
	wire [7:0] uart_rx_byte;
	
	initial begin
		rst_n = 0;
	end
	
	pll echo_pll(.clock_in(clk), .clock_out(pll_clk), .locked(pll_lock));
	
	uart #(.FIFO_DEPTH(32), .RX_ENABLE(1), .TX_ENABLE(1)) myuart(
		.clk(pll_clk), .rst_n(rst_n),
		.baud_div(bauddiv), 
		.uart_tx_start(uart_tx_start), .uart_tx_data_in(uart_tx_data_in), .uart_tx_pin(tx),
		.uart_rx_pin(rx), .uart_rx_read(uart_rx_read), .uart_rx_ready(uart_rx_ready), .uart_rx_byte(uart_rx_byte));
	
	always @(posedge pll_clk) begin
		if (!rst_n && pll_lock) begin
			rst_n <= 1;
		end
	end

	reg [1:0] state;
	
	localparam
		STATE_IDLE=0,
		STATE_WAIT_READ=1,
		STATE_WRITE_BYTE=2,
		STATE_WAIT_WRITE=3;

	always @(posedge pll_clk) begin
		if (rst_n) begin
			case(state)
				STATE_IDLE:
					begin
						if (uart_rx_ready) begin
							// there's a byte to read
							uart_rx_read <= 1'b1;
							state <= STATE_WAIT_READ;
						end
					end
				STATE_WAIT_READ:
					begin
						// waiting for read to ack byte
						uart_rx_read <= 1'b0;				// only want 1 byte from the RX fifo
						state <= STATE_WRITE_BYTE;			// next cycle we'll have the byte
					end
				STATE_WRITE_BYTE:
					begin
						uart_tx_data_in <= uart_rx_byte;	// copy RX byte to TX 
						uart_tx_start <= 1'b1;				// issue write
						state <= STATE_WAIT_WRITE;			// next cycle is waiting for the write to finish
					end
				STATE_WAIT_WRITE:
					begin
						uart_tx_start <= 1'b0;				// only want to write 1 byte
						state <= STATE_IDLE;				// back to idle
					end
			endcase
		end
	end
endmodule
