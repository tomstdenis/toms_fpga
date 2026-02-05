# order is important, TX is our "foundation" block which we manually test the bit signal of
# then we test our RX against the TX
# then we test the UART against the TX and RX
all: test_tx.pass test_rx.pass test_uart.pass

test_uart.pass: tx_uart.v rx_uart.v uart.v uart_tb.v
	verilator --lint-only $^
	iverilog -Wall -o sim.vvp $^
	vvp sim.vvp | tee $@.log
	touch $@

test_rx.pass: tx_uart.v rx_uart.v rx_uart_tb.v
	verilator --lint-only $^
	iverilog -o sim.vvp $^
	vvp sim.vvp | tee $@.log
	touch $@

test_tx.pass: tx_uart.v tx_uart_tb.v
	verilator --lint-only $^
	iverilog -o sim.vvp $^
	vvp sim.vvp | tee $@.log
	touch $@

clean:
	rm -f *.vvp *.vcd *.pass *.log
