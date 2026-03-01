test: test_debug.pass

test_debug.pass: debug.v debug_tb.v
	verilator --lint-only $^
	iverilog -D SIM_MODEL -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

clean:
	rm -f *.vvp *.vcd *.pass *.log
