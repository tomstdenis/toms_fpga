test_nanosram.pass: nanosram.v nanosram_tb.v
	verilator --lint-only $^
	iverilog -D MODEL_SIM -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

clean:
	rm -f *.vvp *.vcd *.pass *.log
