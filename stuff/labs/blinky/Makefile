# if you have multiple modules just toss them here
all: test_blinky.pass

# this tests "blinky.sv" using the test bench in "blinky_tb.sv"
test_blinky.pass: blinky_tb.sv blinky.sv
# lint the code first
		verilator --lint-only $^
# synthesize it with iverilog to something it can run		
		iverilog -g2005-sv -Wall -o sim.vvp $^
# run the simulation and produce a FST format waveform, outputs logs to .log file		
		(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

# remove files not needed anymore
.PHONY: clean
clean:
	rm -f *.vcd *.pass *.log *.vvp