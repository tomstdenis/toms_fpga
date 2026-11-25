test_spi.pass: spi_tb.v
	verilator --lint-only $^
	iverilog -g2005-sv -Wall -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

.PHONY: clean
clean:
	rm -f *pass *vcd *vvp *log
