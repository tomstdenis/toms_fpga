test: ../uart/blocks/test_uart.pass test_debug.pass test_debug_uart.pass

test_debug.pass: debug.v debug_tb.v
	verilator --lint-only $^
	iverilog -D SIM_MODEL -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

test_debug_uart.pass:  debug_uart.v  debug.v debug_uart_tb.v  ../uart/blocks/tx_uart.v ../uart/blocks/rx_uart.v ../uart/blocks/uart.v
	verilator --lint-only $^
	iverilog -D SIM_MODEL -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

../uart/blocks/test_uart.pass:
	make -C ../uart/blocks/

clean:
	rm -f *.vvp *.vcd *.pass *.log
