GOWIN_EDA = ~/gowin/IDE/simlib/gw2a/
test_bsram.pass: ${GOWIN_EDA}/prim_sim.v blocks/gowin_sp.v sp_bram.v sp_bram_tb.v
# gowin's verilog fails verilator...
#	verilator --lint-only $^
	iverilog -o sim.vvp $^
	(vvp sim.vvp -fst > $@.log && touch $@) || cat $@.log

clean:
	rm -f *.vvp *.vcd *.pass *.log
