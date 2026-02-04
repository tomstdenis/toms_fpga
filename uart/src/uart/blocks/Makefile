all: test_tx test_rx

test_rx:
	iverilog -o sim.vvp tx_uart.v rx_uart.v rx_uart_tb.v
	vvp sim.vvp

test_tx:
	iverilog -o sim.vvp tx_uart.v tx_uart_tb.v
	vvp sim.vvp

clean:
	rm -f *.vvp *.vcd
