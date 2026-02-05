all: test_tx.pass test_rx.pass test_uart.pass

test_uart.pass: tx_uart.v rx_uart.v uart.v uart_tb.v
	verilator --lint-only $^
	iverilog -Wall -o sim.vvp $^
	vvp sim.vvp
	touch $@

test_rx.pass: tx_uart.v rx_uart.v rx_uart_tb.v
	verilator --lint-only $^
	iverilog -o sim.vvp $^
	vvp sim.vvp
	touch $@

test_tx.pass: tx_uart.v tx_uart_tb.v
	verilator --lint-only $^
	iverilog -o sim.vvp $^
	vvp sim.vvp
	touch $@

clean:
	rm -f *.vvp *.vcd *.pass
