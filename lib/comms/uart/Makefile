# order is important, TX is our "foundation" block which we manually test the bit signal of
# then we test our RX against the TX
# then we test the UART against the TX and RX
all: test_tx.pass test_rx.pass test_uart.pass

test_uart_sv.pass: uart.sv tx_uart.sv rx_uart.sv uart_tb.sv
	verilator --lint-only $^
	iverilog -g2005-sv -Wall -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

test_uart.pass: uart.v tx_uart.v rx_uart.v uart_tb.v
	verilator --lint-only $^
	iverilog -g2005-sv -Wall -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log
#	verilator --no-sched-zero-delay --binary $^
#	(obj_dir/Vuart > $@.log && touch $@) || cat $@.log

test_rx.pass: rx_uart.sv tx_uart.sv rx_uart_tb.sv
	verilator --lint-only $^
	iverilog -g2005-sv -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log
#	verilator --no-sched-zero-delay --binary $^
#	(obj_dir/Vrx_uart > $@.log && touch $@) || cat $@.log

test_tx.pass: tx_uart.sv tx_uart_tb.sv
	verilator --no-sched-zero-delay --lint-only $^
	iverilog -g2005-sv -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log
#	verilator --no-sched-zero-delay --binary $^
#	(obj_dir/Vtx_uart > $@.log && touch $@) || cat $@.log

clean:
	rm -f *.vvp *.vcd *.pass *.log
	rm -rf obj_dir
