test: blocks/test_uart.pass test_uartmem.pass

blocks/test_uart.pass:
	make -C blocks all

test_uartmem.pass: uart_mem_tb.v uart_mem.v uart_mem.vh blocks/uart.v blocks/rx_uart.v blocks/tx_uart.v
	verilator --lint-only $^
	iverilog -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log


clean:
	rm -f *.vvp *.vcd *.pass *.log
	make -C blocks clean
