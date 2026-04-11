# order is important, TX is our "foundation" block which we manually test the bit signal of
# then we test our RX against the TX
# then we test the UART against the TX and RX
all: test_tx.pass test_rx.pass test_uart.pass

test_uart.pass: tx_uart.sv rx_uart.sv uart.sv uart_tb.sv
	verilator --lint-only $^
	iverilog -g2005-sv -Wall -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

test_rx.pass: tx_uart.sv rx_uart.sv rx_uart_tb.sv
	verilator --lint-only $^
	iverilog -g2005-sv -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

test_tx.pass: tx_uart.sv tx_uart_tb.sv
	verilator --no-sched-zero-delay --lint-only $^
	iverilog -g2005-sv -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

clean:
	rm -f *.vvp *.vcd *.pass *.log
