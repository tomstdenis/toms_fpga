test_spidma.pass: spidma.v spidma_tb.v
	verilator --lint-only $^
	iverilog -D SIM_MODEL -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

clean:
	rm -f *.vvp *.vcd *.pass *.log
