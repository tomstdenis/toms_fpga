test_rx:
	iverilog -o simp.vvp tx_uart.v rx_uart.v rx_uart_tb.v
	vvp sim.vvp

test_tx:
	iverilog -o sim.vvp tx_uart.v tx_uart_tb.v
	vvp sim.vvp

clean:
	rm -f sim.vvp *.vcd
