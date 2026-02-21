test: test_sram.pass

test_sram.pass: sram.v sram_tb.v
	verilator --lint-only $^
	iverilog -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

clean:
	rm -f *.vvp *.vcd *.pass *.log
