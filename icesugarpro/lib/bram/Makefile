all: bram_dp_2048x32.pass bram_dp_nx2048x32.pass

bram_dp_2048x32.pass: DP16KD.v bram_dp_2048x8.v bram_dp_2048x32.v bram_dp_2048x32_tb.v
	verilator --lint-only $^
	iverilog -Wall -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

bram_dp_nx2048x32.pass: DP16KD.v bram_dp_2048x8.v bram_dp_2048x32.v bram_dp_nx2048x32.v bram_dp_nx2048x32_tb.v
	verilator --top-module bram_dp_nx2048x32_tb --lint-only $^
	iverilog -Wall -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

clean:
	rm -f *.vvp *.vcd *.pass *.log
