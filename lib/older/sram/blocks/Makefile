test: test_sram.pass test_sram_flat.pass test_sram_flat_wide.pass test_sram_flat_zc.pass test_sram_flat_wide_zc.pass

test_sram.pass: sram.v sram_tb.v
	verilator --lint-only $^
	iverilog -D SIM_MODEL -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

test_sram_flat.pass: sram_flat.v sram_flat_tb.v
	verilator --lint-only $^
	iverilog -D SIM_MODEL -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

test_sram_flat_zc.pass: sram_flat_zc.v sram_flat_zc_tb.v
	verilator --lint-only $^
	iverilog -D SIM_MODEL -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

test_sram_flat_wide.pass: sram_flat.v sram_flat_wide_tb.v
	verilator --lint-only $^
	iverilog -D SIM_MODEL -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

test_sram_flat_wide_zc.pass: sram_flat_zc.v sram_flat_wide_zc_tb.v
	verilator --lint-only $^
	iverilog -D SIM_MODEL -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

clean:
	rm -f *.vvp *.vcd *.pass *.log
