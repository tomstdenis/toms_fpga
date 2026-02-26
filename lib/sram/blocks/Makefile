test: test_sram_fifo.pass

test_sram_fifo.pass: sram_fifo.v sram_fifo_tb.v
	verilator --lint-only $^
	iverilog -D SIM_MODEL -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

clean:
	rm -f *.vvp *.vcd *.pass *.log
