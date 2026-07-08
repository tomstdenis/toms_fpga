test_p2s.pass: p2s_tb.v p2s.v 
	verilator --lint-only $^
	iverilog -g2005-sv -Wall -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

clean:
	rm -f *.vvp *.log *.vcd *.pass
