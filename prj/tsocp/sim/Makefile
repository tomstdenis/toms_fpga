test_cpu: sim.v ${CPU}
	@verilator -DPROGRAM_HEX="\"../${HEX}\"" -DPROGRAM_STATE="\"../${STATE}\"" --lint-only $^
	@iverilog -g2005-sv -Wall -DPROGRAM_HEX="\"../${HEX}\"" -DPROGRAM_STATE="\"../${STATE}\"" -o sim.vvp $^
	@(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

.PHONY: clean
clean:
	@rm -f sim.vvp *.vcd *.log test_cpu